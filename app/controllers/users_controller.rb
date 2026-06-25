# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class UsersController < ApplicationController
  include RecordPreloader

  before_action :logged_in_user, only: %i[index show edit update destroy following followers]
  before_action :correct_user,   only: %i[edit update]
  before_action :admin_user,     only: :destroy

  def index
    # Eager load avatar attachments to eliminate N+1 queries when rendering the user list
    @users = User.with_attached_avatar.page(params[:page])
  end

  def show
    @user = User.find(params[:id])
    @activities = @user.activities.order(created_at: :desc)
    @likes = @user.likes.order(created_at: :desc)

    # Filter activities and likes based on privacy unless the current user is the owner
    unless current_user?(@user)
      @activities = @activities.joins(
        'INNER JOIN library_items ON library_items.item_id = activities.trackable_id AND ' \
        'library_items.item_type = activities.trackable_type AND library_items.user_id = activities.user_id'
      ).where(library_items: { is_public: true })

      @likes = @likes.joins(
        'INNER JOIN library_items ON library_items.item_id = likes.likeable_id AND ' \
        'library_items.item_type = likes.likeable_type AND library_items.user_id = likes.user_id'
      ).where(library_items: { is_public: true })
    end

    @activities = @activities.limit(20)
    @likes = @likes.to_a

    # Preload social feed (activities and posts)
    @combined_feed = preload_social_feed(@activities.to_a + @user.posts.to_a)
    @combined_feed.sort_by!(&:created_at).reverse!

    # Preload likes
    preload_social_feed(@likes)

    @collection_items = preload_library_items(fetch_library_items(is_collected: true))
    @backlog_items = preload_library_items(fetch_library_items(in_backlog: true))
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
      flash[:success] = 'Welcome to MediaTracker!'
      redirect_to @user
    else
      render 'new', status: :unprocessable_content
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
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
    User.find(params[:id]).destroy
    flash[:success] = 'User deleted'
    redirect_to users_url, status: :see_other
  end

  def following
    @title = 'Following'
    @user  = User.find(params[:id])
    @users = @user.following.page(params[:page])
    render 'show_follow'
  end

  def followers
    @title = 'Followers'
    @user  = User.find(params[:id])
    @users = @user.followers.page(params[:page])
    render 'show_follow'
  end

  private

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
    items = @user.library_items.where(filter)
    items = items.where(is_public: true) unless current_user?(@user)
    items = items.where(item_type: params[:type]) if params[:type].present? && filter[:is_collected]
    items.order(created_at: :desc)
  end

  # Confirms the correct user.
  def correct_user
    @user = User.find(params[:id])
    redirect_to(root_url) unless current_user?(@user)
  end

  # Confirms an admin user.
  def admin_user
    redirect_to(root_url) unless current_user.admin?
  end
end

# rubocop:enable Metrics/ClassLength
