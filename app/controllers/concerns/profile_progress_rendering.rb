# frozen_string_literal: true

# Refresh the whole tracker after a quick action, so totals, ordering, pagination
# and the two-item overview remain correct after completion or dismissal.
module ProfileProgressRendering
  extend ActiveSupport::Concern

  private

  def load_profile_progress
    @progress_type = %w[TvShow Comic VideoGame].include?(params[:type]) ? params[:type] : nil
    @progress_sort = %w[recent title progress].include?(params[:sort]) ? params[:sort] : 'recent'
    tracker = InProgressTracker.new(@user, public_only: !@profile_owner)
    page = [params[:page].to_i, 1].max
    options = { include_games: true, media_type: @progress_type, sort: @progress_sort, limit: 12 }
    items = tracker.items(**options, offset: (page - 1) * 12)
    last_page = [(tracker.total_count / 12.0).ceil, 1].max
    if page > last_page
      page = last_page
      items = tracker.items(**options, offset: (page - 1) * 12)
    end
    @in_progress_items = Kaminari.paginate_array(items, total_count: tracker.total_count).page(page).per(12)
  end

  def render_profile_tracking(error: nil, close_modal: false)
    @user = current_user
    @profile_owner = true
    @profile_tab = params[:profile_tab] == 'progress' ? 'progress' : 'overview'
    response.headers['Cache-Control'] = 'private, no-store'
    if @profile_tab == 'progress'
      load_profile_progress
      partial = 'users/profile_progress'
    else
      @in_progress_items = InProgressTracker.items_for(@user, limit: 2, include_games: true)
      partial = 'users/profile_progress_preview'
    end
    respond_to do |format|
      format.turbo_stream do
        locals = { tracking_error: error, tracking_notice: close_modal ? 'Game tracking updated.' : nil }
        updates = [turbo_stream.replace('in_progress_section', partial: partial, locals: locals)]
        updates << turbo_stream.update('modal', '') if close_modal
        render turbo_stream: updates
      end
      format.html do
        redirect_to user_path(@user, tab: @profile_tab, type: @progress_type, sort: @progress_sort),
                    status: :see_other, alert: error
      end
    end
  end
end
