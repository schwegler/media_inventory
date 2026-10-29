# frozen_string_literal: true

class ComicIssuesController < ApplicationController
  include SeriesCollectionRendering
  include ProfileProgressRendering

  before_action :logged_in_user, only: %i[toggle_read]

  def show
    @comic_issue = ComicIssue.includes(metadata_credits: :metadata_entity).find(params[:id])
    return if redirect_to_canonical_url(@comic_issue)
    return unless logged_in?

    @library_item = LibraryItem.find_by(user: current_user, item: @comic_issue)
  end

  # rubocop:disable-next Metrics/MethodLength, Metrics/AbcSize
  def toggle_read
    @comic_issue = ComicIssue.find(params[:id])

    unless LibraryItem.exists?(user: current_user, item: @comic_issue.comic)
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @comic_issue)

    if ConsumptionPasses.apply(current_user, @comic_issue, @library_item, comic_issue_params)
      return render_profile_tracking if params[:profile_tracking] == '1'

      respond_to do |format|
        if params[:back_to_issue]
          format.html { redirect_to @comic_issue, notice: 'Issue updated.' }
          format.turbo_stream { redirect_to @comic_issue, notice: 'Issue updated.' }
        elsif params[:in_progress]
          @comic = @comic_issue.comic
          @in_progress_item = InProgressTracker.item_for(current_user, @comic)
          format.turbo_stream { render 'in_progress/update_comic' }
          format.html { redirect_back fallback_location: @comic, notice: "Logged #{@comic_issue.display_title}." }
        else
          @comic_library_item = LibraryItem.find_by(user: current_user, item: @comic_issue.comic)
          @active_pass = ConsumptionPasses.current_pass(@comic_library_item)
          @active_pass_entry_ids = ConsumptionPasses.pass_entry_ids(@active_pass)
          format.turbo_stream do
            if params[:series_page] == '1'
              render_series_collection(@comic_issue.comic, @comic_library_item)
            else
              render :toggle_read
            end
          end
          format.html { redirect_back fallback_location: @comic_issue.comic, notice: 'Issue updated.' }
        end
      end
    else
      if params[:profile_tracking] == '1'
        return render_profile_tracking(error: 'Could not log this issue. Please try again.')
      end

      respond_to do |format|
        format.html { redirect_back fallback_location: @comic_issue.comic, alert: 'Failed to update issue.' }
      end
    end
  end

  private

  def comic_issue_params
    params.require(:comic_issue).permit(:consumed, :consumed_at, :rating, :review, :is_public)
  end
end
