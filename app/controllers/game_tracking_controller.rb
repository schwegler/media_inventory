# frozen_string_literal: true

# All personal tracking is scoped through the signed-in user's library. It is
# never rendered on public catalog pages or included in the activity feed.
class GameTrackingController < ApplicationController
  before_action :logged_in_user
  before_action :load_library

  def create
    record = case params[:kind]
             when 'copy' then @library.game_copies.new(copy_params)
             when 'playthrough' then @library.game_playthroughs.new(playthrough_params)
             when 'journal' then @library.game_journal_entries.new(params.require(:journal).permit(:body, :spoiler))
             when 'session'
               @library.game_playthroughs.find(params[:playthrough_id]).game_sessions.new(session_params)
             else return head :bad_request
             end
    if record.save
      redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'), notice: 'Gaming record saved.',
                                                                              status: :see_other
    else
      redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'),
                  alert: record.errors.full_messages.join(', '), status: :see_other
    end
  end

  def update
    record = params[:kind] == 'copy' ? @library.game_copies.find(params[:id]) : @library.game_playthroughs.find(params[:id])
    fields = params[:kind] == 'copy' ? copy_params : playthrough_params
    if record.update(fields)
      redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'), notice: 'Progress updated.',
                                                                              status: :see_other
    else
      redirect_to video_game_path(@library.item), alert: record.errors.full_messages.join(', '), status: :see_other
    end
  end

  def export
    response.headers['Cache-Control'] = 'private, no-store'
    if params[:format] == 'csv'
      send_data GameCollectionExport.csv(@library), filename: "game-#{@library.item_id}-copies.csv", type: 'text/csv'
    else
      send_data GameCollectionExport.json(@library), filename: "game-#{@library.item_id}.json", type: 'application/json'
    end
  end

  private

  def load_library
    @library = current_user.library_items.where(item_type: 'VideoGame').find_by!(item_id: params[:video_game_id])
  end

  def copy_params
    params.require(:copy).permit(:platform, :storefront, :edition, :ownership_status, :access_method,
                                 :purchase_date, :purchase_price, :currency, :notes)
  end

  def playthrough_params
    params.require(:playthrough).permit(:platform, :status, :difficulty, :route, :progress, :started_on, :completed_on,
                                        :notes)
  end

  def session_params
    params.require(:session).permit(:started_at, :ended_at, :notes, :milestones)
  end
end
