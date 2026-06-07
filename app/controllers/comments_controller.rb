# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :logged_in_user

  def create
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
