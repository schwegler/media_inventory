# frozen_string_literal: true

# All personal tracking is scoped through the signed-in user's library. It is
# never rendered on public catalog pages or included in the activity feed.
class GameTrackingController < ApplicationController
  before_action :logged_in_user
  before_action :load_library

  def create
    record = tracking_scope.new(tracking_params)
    if record.save
      redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'), notice: 'Gaming record saved.',
                                                                              status: :see_other
    else
      redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'),
                  alert: record.errors.full_messages.join(', '), status: :see_other
    end
  end

  def update
    record = tracking_scope.find(params[:id])
    fields = tracking_params
    if record.update(fields)
      redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'), notice: 'Gaming record updated.',
                                                                              status: :see_other
    else
      redirect_to video_game_path(@library.item), alert: record.errors.full_messages.join(', '), status: :see_other
    end
  end

  def destroy
    tracking_scope.find(params[:id]).destroy!
    redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'), notice: 'Gaming record removed.',
                                                                            status: :see_other
  end

  def preferences
    fields = params.require(:preferences).permit(:game_favorite, :game_activity_public, :tags)
    tags = fields.delete(:tags).to_s.split(',').map(&:strip).reject(&:blank?).uniq
    if @library.update(fields.merge(game_tags: tags))
      redirect_to video_game_path(@library.item), notice: 'Game organization updated.', status: :see_other
    else
      redirect_to video_game_path(@library.item), alert: @library.errors.full_messages.join(', '), status: :see_other
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

  def tracking_scope
    case params[:kind]
    when 'copy' then @library.game_copies
    when 'playthrough', nil then @library.game_playthroughs
    when 'journal' then @library.game_journal_entries
    when 'milestone' then @library.game_milestones
    when 'session'
      return @library.game_playthroughs.find(params[:playthrough_id]).game_sessions if action_name == 'create'

      GameSession.where(game_playthrough_id: @library.game_playthroughs.select(:id))
    else raise ActionController::BadRequest, 'Unsupported gaming record'
    end
  end

  def tracking_params
    case params[:kind]
    when 'copy' then params.require(:copy).permit(*GameCollectionImport::COPY_FIELDS)
    when 'journal' then params.require(:journal).permit(:body, :spoiler)
    when 'milestone' then params.require(:milestone).permit(*GameCollectionImport::MILESTONE_FIELDS)
    when 'session' then params.require(:session).permit(*GameCollectionImport::SESSION_FIELDS)
    else params.require(:playthrough).permit(*GameCollectionImport::PLAY_FIELDS)
    end
  end
end
