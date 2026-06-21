# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :logged_in_user

  def create
    commentable_type = params.dig(:comment, :commentable_type)
    commentable_id = params.dig(:comment, :commentable_id)

    allowed_types = %w[Movie TvShow TvEpisode Album Comic ComicIssue VideoGame Book Post LibraryItem]
    unless allowed_types.include?(commentable_type)
      redirect_to root_path, alert: 'Invalid commentable type.'
      return
    end

    commentable = commentable_type.constantize.find_by(id: commentable_id)
    unless can_access?(commentable)
      redirect_to root_path, alert: 'Not authorized to comment on this item.'
      return
    end

    @comment = current_user.comments.build(comment_params)
    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path, notice: 'Comment added.' }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: root_path, alert: 'Error creating comment.' }
      end
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:content, :commentable_type, :commentable_id)
  end
end
