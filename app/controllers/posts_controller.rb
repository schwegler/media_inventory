# frozen_string_literal: true

class PostsController < ApplicationController
  before_action :logged_in_user

  def show
    @post = Post.find(params[:id])
    # Ensure user has permission to view this post
    redirect_to root_path, alert: 'Not authorized' and return unless can_access?(@post)
  end

  def create
    @post = current_user.posts.build(post_params)
    if @post.save
      redirect_back fallback_location: user_path(current_user), notice: 'Post created successfully.'
    else
      redirect_back fallback_location: user_path(current_user), alert: 'Failed to create post.'
    end
  end

  def destroy
    # Use find_by to avoid raising ActiveRecord::RecordNotFound
    @post = current_user.posts.find_by(id: params[:id])
    if @post&.destroy
      redirect_back fallback_location: user_path(current_user), notice: 'Post deleted.'
    else
      redirect_back fallback_location: user_path(current_user), alert: 'Unable to delete post.'
    end
  end

  private

  def post_params
    params.require(:post).permit(:content)
  end
end
