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
    # `is_public` only governs review/rating visibility, so every collected item counts.
    @public_collection_counts = LibraryItem.where(user_id: @users.map(&:id), is_collected: true)
                                           .group(:user_id).count
  end

  def show
    return if load_canonical_profile

    prepare_profile_library

    # PERFORMANCE OPTIMIZATION: Conditionally fetch and preload data strictly required for the active profile tab.
    # This avoids dozens of redundant SQL queries (activities, posts, likes, in-progress items, and cover preloading)
    # when viewing non-overview tabs like 'collection', 'backlog', 'posts', or 'likes'.
    @collection_items = []
    @backlog_items = []
    @recent_collection = []
    @in_progress_items = []
    @combined_feed = []
    @likes = []

    case @profile_tab
    when 'overview'
      @in_progress_items = InProgressTracker.items_for(@user)
      recent = @visible_library.where(is_collected: true).order(created_at: :desc).limit(6)
      @recent_collection = preload_library_items(recent)
      @combined_feed = fetch_combined_feed
    when 'collection'
      @collection_items = preload_library_items(fetch_library_items(is_collected: true))
    when 'backlog'
      @backlog_items = preload_library_items(fetch_library_items(in_backlog: true))
    when 'posts'
      @combined_feed = fetch_combined_feed
    when 'likes'
      @likes = fetch_likes
    end

    @profile_favorites = profile_favorites
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

  def load_canonical_profile
    @user = if params[:username].present?
              User.where('LOWER(username) = ?', params[:username].to_s.downcase).first!
            else
              User.find_by_profile_param!(params[:id])
            end
    canonical = @user.username.present? ? handle_profile_path(@user.username) : user_path(@user)
    return false if request.path == canonical

    canonical += "?#{request.query_string}" if request.query_string.present?
    redirect_to canonical, status: :moved_permanently
  end

  def prepare_profile_library
    @profile_owner = current_user?(@user) && params[:preview] != 'public'
    @profile_tab = %w[overview collection backlog posts likes].include?(params[:tab]) ? params[:tab] : 'overview'
    # `is_public` controls review/rating visibility only; every library entry is visible on the profile.
    @visible_library = @user.library_items
    @collection_count = @visible_library.where(is_collected: true).count
    @backlog_count = @visible_library.where(in_backlog: true).count
    @library_mix = @visible_library.where(is_collected: true).group(:item_type).count
  end

  def profile_favorites
    return [] unless @profile_tab == 'overview'

    (@user.favorite_shelves.find_by(category: 'overall')&.items || []).first(3)
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

  # Non-review activities (added, consumed, watchlist) are always shown. "reviewed" activities
  # expose review/rating content, so they're only shown when the underlying entry is public.
  def public_review_activities(scope)
    public_reviews = public_library_events(Activity.where(activity_type: 'reviewed'), 'activities', 'trackable')
    scope.where.not(activity_type: 'reviewed').or(scope.where(id: public_reviews.select(:id)))
  end

  def public_library_events(scope, table, association)
    t = ActiveRecord::Base.connection.quote_table_name(table)
    a_type = ActiveRecord::Base.connection.quote_column_name("#{association}_type")
    a_id = ActiveRecord::Base.connection.quote_column_name("#{association}_id")

    scope.where('EXISTS (SELECT 1 FROM library_items WHERE library_items.is_public = ? AND ' \
                "((#{t}.#{a_type} = 'LibraryItem' AND library_items.id = #{t}.#{a_id}) OR " \
                "(library_items.item_type = #{t}.#{a_type} AND " \
                "library_items.item_id = #{t}.#{a_id} " \
                "AND library_items.user_id = #{t}.user_id)))", true)
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

  def fetch_combined_feed
    activities = @user.activities.order(created_at: :desc)
    activities = public_review_activities(activities) unless @profile_owner
    activities = activities.limit(20)

    combined = preload_social_feed(activities.to_a + @user.posts.order(created_at: :desc).limit(20).to_a)
    combined.sort_by!(&:created_at).reverse!
    combined.first(20)
  end

  def fetch_likes
    likes = @user.likes.order(created_at: :desc)
    likes = public_library_events(likes, 'likes', 'likeable') unless @profile_owner
    likes = likes.limit(24).to_a
    preload_social_feed(likes)
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
