# frozen_string_literal: true

class VideoGamesController < InventoryController
  before_action :logged_in_user, only: %i[new create edit update destroy sync_steam]

  def create
    super
  rescue GameCatalogIdentity::Invalid => e
    @video_game = VideoGame.new(resource_params.except(:catalog_selection))
    @video_game.errors.add(:base, e.message)
    render :new, status: :unprocessable_content
  end

  def sync_steam
    return head :unprocessable_content unless params[:authorized] == '1' && params[:steam_id].to_s.match?(/\A\d{17}\z/)

    state = SteamLibraryImporter.call(current_user, params[:steam_id])
    messages = { 'ready' => 'Steam library imported. Manual data was preserved.',
                 'cooldown' => 'Wait five minutes between sync attempts.',
                 'failed' => 'Steam library unavailable. Check visibility and Web API configuration.' }
    redirect_to video_games_path(library: 'mine'), status: :see_other, notice: messages.fetch(state)
  end

  def index
    @personal_library = params[:library] == 'mine' || params[:view].present?
    return redirect_to login_path unless logged_in? || !@personal_library

    response.headers['Cache-Control'] = 'private, no-store' if @personal_library

    @saved_view = current_user.game_library_views.find(params[:view]) if params[:view].present?
    @filters = (@saved_view&.filters || {}).merge(GameLibraryQuery.normalize(params))
    @layout = %w[grid list table].include?(@filters['layout']) ? @filters['layout'] : 'grid'
    @video_games = GameLibraryQuery.new(@filters,
                                        user: @personal_library ? current_user : nil).call.page(params[:page]).per(CATALOG_PAGE_SIZE)
    prepare_library if @personal_library
  end

  def show
    super
    return if performed?

    @artworks = @video_game.game_artworks.where(library_item_id: [nil, @library_item&.id])
                           .with_attached_image.includes(image_attachment: { blob: { artwork_renditions: :blob } })
                           .order(created_at: :desc).limit(20)
  end

  private

  def resolve_catalog_resource(attributes)
    token = attributes.delete(:catalog_selection)
    GameCatalogIdentity.resolve(attributes, token)
  end

  def prepare_library
    @game_statistics = GameLibraryStatistics.call(current_user)
    libraries = current_user.library_items.where(item_type: 'VideoGame')
    @libraries = libraries.where(item_id: @video_games.map(&:id))
                          .includes(:game_copies, :game_playthroughs,
                                    game_cover_image_attachment: { blob: { artwork_renditions: :blob } })
                          .index_by(&:item_id)
    copies = GameCopy.where(library_item_id: libraries.select(:id))
    @platforms = copies.distinct.order(:platform).pluck(:platform)
    @storefronts = copies.where.not(storefront: [nil, '']).distinct.order(:storefront).pluck(:storefront)
    @saved_views = current_user.game_library_views.order(:name)
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
      :catalog_selection, :copy_platform, :storefront, :edition, :access_method, :ownership_status, :play_status,
      :title, :game_type, :developer, :publisher, :platform, :release_year, :rating, :is_public, :thumbnail_url,
      :in_watchlist,
      :is_collected, :consumed, :consumed_at, :review, :cover_image, :api_id, :external_url,
      :owned_physically, :owned_physically_format, :owned_digitally, :owned_digitally_format
    )
  end
end
