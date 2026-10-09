# frozen_string_literal: true

class VideoGamesController < InventoryController
  before_action :logged_in_user, only: %i[new create edit update destroy sync_steam]

  def sync_steam
    return head :unprocessable_content unless params[:authorized] == '1' && params[:steam_id].to_s.match?(/\A\d{17}\z/)

    state = SteamLibraryImporter.call(current_user, params[:steam_id])
    messages = { 'ready' => 'Steam library imported. Manual data was preserved.',
                 'cooldown' => 'Wait five minutes between sync attempts.',
                 'failed' => 'Steam library unavailable. Check visibility and Web API configuration.' }
    redirect_to video_games_path(library: 'mine'), status: :see_other, notice: messages.fetch(state)
  end

  def index
    scope = VideoGame.with_attached_cover_image
    if params[:library] == 'mine' && logged_in?
      scope = scope.joins(:library_items).where(library_items: { user_id: current_user.id }).distinct
    end
    if params[:q].present?
      scope = scope.where('LOWER(video_games.title) LIKE ?', "%#{VideoGame.sanitize_sql_like(params[:q].downcase)}%")
    end
    scope = scope.where(game_type: params[:game_type]) if %w[game dlc soundtrack unknown].include?(params[:game_type])
    sort = { 'title' => { title: :asc }, 'release' => { release_year: :desc }, 'added' => { created_at: :desc } }
    @game_statistics = personal_statistics if logged_in? && params[:library] == 'mine'
    @video_games = scope.order(sort.fetch(params[:sort], sort['added'])).page(params[:page])
  end

  private

  def personal_statistics
    libraries = current_user.library_items.where(item_type: 'VideoGame')
    copies = GameCopy.where(library_item_id: libraries.select(:id))
    { unique_games: libraries.distinct.count(:item_id),
      owned_copies: copies.where(ownership_status: 'owned', access_method: %w[physical digital]).count,
      subscription_access: copies.where(access_method: 'subscription').count }
  end

  def after_library_saved
    fields = resource_params
    if fields[:copy_platform].present?
      @library_item.game_copies.find_or_create_by!(platform: fields[:copy_platform], storefront: fields[:storefront],
                                                   edition: fields[:edition],
                                                   ownership_status: fields[:ownership_status].presence || 'owned',
                                                   access_method: fields[:access_method].presence || 'digital')
    end
    return unless fields[:play_status].present?

    @library_item.game_playthroughs.find_or_create_by!(status: fields[:play_status], platform: fields[:copy_platform])
  end

  def resource_params
    params.require(:video_game).permit(
      :copy_platform, :storefront, :edition, :access_method, :ownership_status, :play_status,
      :title, :game_type, :developer, :publisher, :platform, :release_year, :rating, :is_public, :thumbnail_url,
      :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :cover_image, :api_id, :external_url,
      :owned_physically, :owned_physically_format, :owned_digitally, :owned_digitally_format
    )
  end
end
