# frozen_string_literal: true

# All personal tracking is scoped through the signed-in user's library. It is
# never rendered on public catalog pages or included in the activity feed.
class GameTrackingController < ApplicationController
  before_action :logged_in_user
  before_action :load_library

  def new
    @kind = params[:kind].presence || 'journal'
    if @kind == 'session'
      @playthrough = @library.game_playthroughs.find(params[:playthrough_id] || @library.game_playthroughs.first&.id)
      @record = @playthrough.game_sessions.new(started_at: 1.hour.ago.change(sec: 0),
                                               ended_at: Time.current.change(sec: 0))
    else
      @record = tracking_scope.new
    end
  end

  def edit
    @kind = params[:kind].presence || 'journal'
    @record = tracking_scope.find(params[:id])
    @playthrough = @record.game_playthrough if @kind == 'session'
  end

  def create
    record = tracking_scope.new(tracking_params)
    record.save ? render_tracking_stream('Gaming record saved.') : render_tracking_error(record, :new)
  end

  def update
    record = tracking_scope.find(params[:id])
    record.update(tracking_params) ? render_tracking_stream('Gaming record updated.') : render_tracking_error(record, :edit)
  end

  def destroy
    tracking_scope.find(params[:id]).destroy!
    render_tracking_stream('Gaming record removed.')
  end

  def preferences
    fields = params.require(:preferences).permit(:game_favorite, :game_activity_public, :tags)
    tags = fields.delete(:tags).to_s.split(',').map(&:strip).reject(&:blank?).uniq
    path = video_game_path(@library.item)
    if @library.update(fields.merge(game_tags: tags))
      redirect_to path, notice: 'Game organization updated.', status: :see_other
    else
      redirect_to path, alert: @library.errors.full_messages.join(', '), status: :see_other
    end
  end

  def export
    response.headers['Cache-Control'] = 'private, no-store'
    csv = params[:format] == 'csv'
    name = "game-#{@library.item_id}#{csv ? '-copies.csv' : '.json'}"
    send_data(csv ? GameCollectionExport.csv(@library) : GameCollectionExport.json(@library),
              filename: name, type: (csv ? 'text/csv' : 'application/json'))
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
      return @library.game_playthroughs.find(params[:playthrough_id]).game_sessions if %w[create new].include?(action_name)

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

  def render_tracking_stream(notice)
    @library.reload
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace('my-game-tracking', partial: 'video_games/tracking', locals: { library: @library }),
          turbo_stream.update('modal', '')
        ]
      end
      format.html do
        redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'), notice: notice, status: :see_other
      end
    end
  end

  def render_tracking_error(record, action)
    respond_to do |format|
      format.turbo_stream do
        @kind = params[:kind].presence || 'journal'
        @record = record
        @playthrough = @record.try(:game_playthrough) || @library.game_playthroughs.find_by(id: params[:playthrough_id])
        flash.now[:alert] = record.errors.full_messages.join(', ')
        render action, status: :unprocessable_entity
      end
      format.html do
        redirect_to video_game_path(@library.item, anchor: (action == :edit ? nil : 'my-game-tracking')),
                    alert: record.errors.full_messages.join(', '), status: :see_other
      end
    end
  end
end
