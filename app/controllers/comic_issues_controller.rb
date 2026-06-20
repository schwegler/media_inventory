# frozen_string_literal: true

class ComicIssuesController < ApplicationController
  before_action :logged_in_user, only: %i[toggle_read]

  def show
    @comic_issue = ComicIssue.find(params[:id])
    return unless logged_in?

    @library_item = LibraryItem.find_by(user: current_user, item: @comic_issue)
  end

  def toggle_read
    @comic_issue = ComicIssue.find(params[:id])

    unless LibraryItem.exists?(user: current_user, item: @comic_issue.comic)
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @comic_issue)

    if @library_item.update(comic_issue_params)
      respond_to do |format|
        if params[:back_to_issue]
          format.html { redirect_to @comic_issue, notice: 'Issue updated.' }
          format.turbo_stream { redirect_to @comic_issue, notice: 'Issue updated.' }
        else
          format.turbo_stream
          format.html { redirect_back fallback_location: @comic_issue.comic, notice: 'Issue updated.' }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: @comic_issue.comic, alert: 'Failed to update issue.' }
      end
    end
  end

  private

  def comic_issue_params
    params.require(:comic_issue).permit(:consumed, :consumed_at, :rating, :review)
  end
end
