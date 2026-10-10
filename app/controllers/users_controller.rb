# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class UsersController < ApplicationController
  include RecordPreloader

  before_action :logged_in_user, only: %i[index edit update destroy]
  before_action :correct_user,   only: %i[edit update]
  before_action :admin_user,     only: :destroy

  def index
    # Optimize to eager load user avatars to prevent N+1 queries when rendering the user list
    @users = User.with_attached_avatar.with_attached_header_banner.page(params[:page])
    @public_collection_counts = LibraryItem.where(user_id: @users.map(&:id), is_collected: true, is_public: true)
                                           .group(:user_id).count
  end

  def show
    @user = User.find_by_profile_param!(params[:id])
    return if redirect_to_canonical_url(@user)

    prepare_profile_library
    @activities = @user.activities.order(created_at: :desc)
    @likes = @user.likes.order(created_at: :desc)

    # Filter activities and likes based on privacy unless the current user is the owner
    unless @profile_owner
      @activities = public_library_events(@activities, 'activities', 'trackable')
      @likes = public_library_events(@likes, 'likes', 'likeable')
    end

    @activities = @activities.limit(20)
    @likes = @likes.limit(24).to_a

    # Preload social feed (activities and posts)
    @combined_feed = preload_social_feed(@activities.to_a + @user.posts.order(created_at: :desc).limit(20).to_a)
    @combined_feed.sort_by!(&:created_at).reverse!
    @combined_feed = @combined_feed.first(20)

    # Preload likes
    preload_social_feed(@likes)

    # PERFORMANCE OPTIMIZATION: Conditionally fetch and preload full page collections only when their tab is active
    # to avoid redundant SQL queries and cover image attachment preloading on other profile tabs.
    @collection_items = @profile_tab == 'collection' ? preload_library_items(fetch_library_items(is_collected: true)) : []
    @backlog_items = @profile_tab == 'backlog' ? preload_library_items(fetch_library_items(in_backlog: true)) : []
    @recent_collection = preload_library_items(@visible_library.where(is_collected: true).order(created_at: :desc).limit(6))
    @in_progress_items = InProgressTracker.items_for(@user, public_only: !@profile_owner)
    load_shared_items
  end

  def new
    @user = User.new
  end

  def create
    adjusted_params = user_params.dup

    @user = User.new(adjusted_params)
    @user.confirmed_at = Time.current # Automatically confirmed via password signup
    if @user.save
      reset_session
      log_in @user
      flash[:success] = 'Welcome to Trove!'
      redirect_to @user
    else
      render 'new', status: :unprocessable_content
    end
  end

  def edit
    @user = User.find_by_profile_param!(params[:id])
  end

  def update
    @user = User.find_by_profile_param!(params[:id])
    update_params = user_params.dup
    if update_params[:password].blank? && update_params[:password_confirmation].blank?
      update_params.delete(:password)
      update_params.delete(:password_confirmation)
    end

    if @user.update(update_params)
      flash[:success] = 'Profile updated'
      redirect_to @user
    else
      render 'edit', status: :unprocessable_content
    end
  end

  def destroy
    User.find_by_profile_param!(params[:id]).destroy
    flash[:success] = 'User deleted'
    redirect_to users_url, status: :see_other
  end

  def following
    @title = 'Following'
    @user  = User.find_by_profile_param!(params[:id])
    # Optimize to eager load user avatars to prevent N+1 queries when rendering following user cards
    @users = @user.following.with_attached_avatar.page(params[:page])
    render 'show_follow'
  end

  def followers
    @title = 'Followers'
    @user  = User.find_by_profile_param!(params[:id])
    # Optimize to eager load user avatars to prevent N+1 queries when rendering followers user cards
    @users = @user.followers.with_attached_avatar.page(params[:page])
    render 'show_follow'
  end

  private

  def prepare_profile_library
    @profile_owner = current_user?(@user) && params[:preview] != 'public'
    @profile_tab = %w[overview collection backlog posts likes].include?(params[:tab]) ? params[:tab] : 'overview'
    @visible_library = @user.library_items
    @visible_library = @visible_library.where(is_public: true) unless @profile_owner
    @collection_count = @visible_library.where(is_collected: true).count
    @backlog_count = @visible_library.where(in_backlog: true).count
    @library_mix = @visible_library.where(is_collected: true).group(:item_type).count
  end

  def load_shared_items
    @shared_items = []
    return unless logged_in? && !current_user?(@user)

    shared = @visible_library.where(is_collected: true).where(
      'EXISTS (SELECT 1 FROM library_items own WHERE own.user_id = ? AND own.is_collected = ? ' \
      'AND own.item_type = library_items.item_type AND own.item_id = library_items.item_id)', current_user.id, true
    )
    @shared_items_count = shared.count
    @shared_items = shared.order(created_at: :desc).limit(4)
    preload_library_items(@shared_items)
  end

  def public_library_events(scope, table, association)
    scope.where('EXISTS (SELECT 1 FROM library_items WHERE library_items.is_public = ? AND ' \
                "((#{table}.#{association}_type = 'LibraryItem' AND library_items.id = #{table}.#{association}_id) OR " \
                "(library_items.item_type = #{table}.#{association}_type AND " \
                "library_items.item_id = #{table}.#{association}_id " \
                "AND library_items.user_id = #{table}.user_id)))", true)
  end

  def user_params
    params.require(:user).permit(
      :name, :username, :email, :password, :password_confirmation,
      :avatar, :header_banner, :bio, :birthday,
      :bsky_handle, :bsky_post_reviews_only, :bsky_custom_message,
      :bsky_post_activity, :bsky_post_reviews,
      :bsky_message_activity_template, :bsky_message_review_template,
      :mastodon_post_activity, :mastodon_post_reviews,
      :mastodon_message_activity_template, :mastodon_message_review_template,
      :notify_email_posts, :notify_email_comments,
      :notify_email_likes, :notify_email_follows,
      :notify_push_posts, :notify_push_comments,
      :notify_push_likes, :notify_push_follows
    )
  end

  def fetch_library_items(filter)
    items = @visible_library.where(filter)
    items = items.where(item_type: params[:type]) if %w[Movie TvShow Album Comic Book VideoGame].include?(params[:type])
    items.order(created_at: :desc).page(params[:page]).per(24)
  end

  # Confirms the correct user.
  def correct_user
    @user = User.find_by_profile_param!(params[:id])
    redirect_to(root_url) unless current_user?(@user)
  end

  # Confirms an admin user.
  def admin_user
    redirect_to(root_url) unless current_user.admin?
  end
end

# rubocop:enable Metrics/ClassLength
