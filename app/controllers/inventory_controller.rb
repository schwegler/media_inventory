# frozen_string_literal: true

# rubocop:disable-next Metrics/ClassLength
class InventoryController < ApplicationController
  include RecordPreloader
  include SeriesCollectionRendering

  CATALOG_PAGE_SIZE = 24
  # Centralize authentication filter for all mutating inventory actions
  before_action :logged_in_user, only: %i[new create edit update destroy]
  around_action :serialize_signed_import, only: :create

  def index
    @personal_library = params[:library] == 'mine'
    return redirect_to login_path if @personal_library && !logged_in?

    response.headers['Cache-Control'] = 'private, no-store' if @personal_library
    scope = resource_class
    # Eager load ActiveStorage attachments/blobs for cover images to prevent N+1 queries when rendering media card grids
    scope = scope.with_attached_cover_image if scope.respond_to?(:with_attached_cover_image)

    @resources = catalog_scope(scope).page(params[:page]).per(CATALOG_PAGE_SIZE)
    preload_card_ratings(@resources.to_a)
    instance_variable_set("@#{resource_name.pluralize}", @resources)
    prepare_media_library if @personal_library
    return unless params[:q].present?

    @match_context = { resource_class.name => MetadataMatchContext.call(@resources.to_a,
                                                                        params[:q]) }
  end

  def new
    @resource = resource_class.new
    prepare_discovery_selection if params[:discovery] == '1'
    instance_variable_set("@#{resource_name}", @resource)
  end

  # rubocop:disable Metrics/MethodLength
  def create
    global_params = resource_params.except(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public, :owned_physically, :owned_physically_format,
                                           :owned_digitally, :owned_digitally_format)
    library_params = personal_library_params

    global_params = imported_attributes(global_params)
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)
    @resource = selected_import_resource(global_params)
    assign_logged_attributes(global_params)
    instance_variable_set("@#{resource_name}", @resource)

    saved = save_logged_resource(library_params)

    if saved
      session.delete(:discovery_intent) if @imported
      record_import_baseline
      enqueue_initial_metadata
      respond_to do |format|
        format.html { redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully logged." }
      end
    else
      respond_to do |format|
        format.html { render :new, status: failure_status }
      end
    end
    # rubocop:enable Metrics/MethodLength
  rescue MetadataImport::Invalid => e
    @resource = resource_class.new(resource_params.except(:import_selection, :catalog_selection))
    @resource.errors.add(:base, e.message)
    instance_variable_set("@#{resource_name}", @resource)
    render :new, status: failure_status
  end

  def show
    @resource = resource_class.find(params[:id])
    preload_entity_credits
    return if redirect_to_canonical_url(@resource)

    if logged_in?
      @library_item = LibraryItem.find_by(user: current_user, item: @resource)
      assign_library_attributes if @library_item
    end
    instance_variable_set("@#{resource_name}", @resource)
    prepare_child_display
  end

  def edit
    @resource = resource_class.find(params[:id])
    @library_item = LibraryItem.find_by(user: current_user, item: @resource)
    unless @library_item
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    @resource.is_collected = @library_item.is_collected
    @resource.in_watchlist = @library_item.in_backlog
    @resource.in_backlog = @library_item.in_backlog
    @resource.rating = @library_item.rating
    @resource.review = @library_item.review
    @resource.consumed = @library_item.consumed
    @resource.consumed_at = @library_item.consumed_at
    @resource.is_public = @library_item.is_public
    @resource.owned_physically = @library_item.owned_physically
    @resource.owned_physically_format = @library_item.owned_physically_format
    @resource.owned_digitally = @library_item.owned_digitally
    @resource.owned_digitally_format = @library_item.owned_digitally_format

    instance_variable_set("@#{resource_name}", @resource)
  end

  def update
    @resource = resource_class.find(params[:id])
    @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @resource)

    global_params = resource_params.except(:import_selection, :is_collected, :in_watchlist, :in_backlog,
                                           :rating, :review, :consumed,
                                           :consumed_at, :is_public, :owned_physically, :owned_physically_format,
                                           :owned_digitally, :owned_digitally_format)
    library_params = personal_library_params
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    ActiveRecord::Base.transaction do
      @resource.update!(global_params) if global_params.to_h.any?
      @library_item.update!(library_params)
      after_library_saved
    end

    instance_variable_set("@#{resource_name}", @resource)
    assign_library_attributes
    flash.now[:notice] = "#{resource_class.model_name.human} was successfully updated."
    respond_to do |format|
      format.html { redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully updated." }
      format.turbo_stream
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.html { render :edit, status: failure_status }
    end
  end

  def destroy
    @resource = resource_class.find(params[:id])
    @library_item = LibraryItem.find_by(user: current_user, item: @resource)

    if @library_item
      @library_item.destroy
      respond_to do |format|
        format.html do
          redirect_to send("#{resource_name.pluralize}_path"),
                      notice: "#{resource_class.model_name.human} was successfully removed from your library.",
                      status: :see_other
        end
      end
    else
      redirect_to root_path, alert: 'Not authorized', status: :see_other
    end
  end

  private

  # Turbo renders the same personal controls as show; the catalog record's
  # virtual form attributes must reflect the saved library entry first.
  def assign_library_attributes
    fields = %w[is_collected rating review consumed consumed_at is_public owned_physically
                owned_physically_format owned_digitally owned_digitally_format]
    @resource.assign_attributes(@library_item.attributes.slice(*fields))
    @resource.in_watchlist = @library_item.in_backlog
    @resource.in_backlog = @library_item.in_backlog
  end

  def assign_logged_attributes(attributes)
    if @resource.persisted?
      return if @resource.is_a?(VideoGame)

      attributes = attributes.slice(:cover_image).compact_blank
    end
    @resource.assign_attributes(attributes)
  end

  def save_logged_resource(library_params)
    saved = false
    ActiveRecord::Base.transaction do
      if @resource.save
        @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @resource)
        @library_item.assign_attributes(library_params)
        @library_item.save!
        after_library_saved
        saved = true
      end
    end

    saved
  end

  def personal_library_params
    resource_params.slice(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed, :consumed_at,
                          :is_public, :owned_physically, :owned_physically_format,
                          :owned_digitally, :owned_digitally_format)
  end

  def serialize_signed_import(&)
    token = params.dig(resource_name, :import_selection)
    data = MetadataImport.read(token, resource_name) if token.present?
  rescue MetadataImport::Invalid
    yield # create renders the established validation error
  else
    data ? ShelfCatalogImport.synchronize(resource_class, data, &) : yield
  end

  def prepare_discovery_selection
    intent = discovery_intent
    return unless intent && intent[:type] == resource_name

    @discovery_selection = MetadataImport.read(intent[:selection], resource_name)
    @discovery_selection[:import_selection] = intent[:selection]
    @discovery_query = intent[:query]
    response.headers['Cache-Control'] = 'private, no-store'
  rescue MetadataImport::Invalid => e
    redirect_to discovery_search_path, alert: e.message
  end

  def imported_attributes(attributes)
    token = attributes.delete(:import_selection)
    @imported = MetadataImport.read(token, resource_name) if token.present?
    return attributes unless @imported

    result = MetadataImport.attributes(@imported, resource_class).merge(attributes.slice(:cover_image))
    result[:thumbnail_url] = @imported[:cover_source_url] if @imported[:cover_source_url].present?
    result
  end

  def selected_import_resource(attributes)
    if @imported && resource_class == VideoGame
      resource = resolve_catalog_resource(attributes.merge(catalog_selection: @imported[:catalog_selection]))
      resource.importing_metadata = true
      return resource
    end
    resource = if @imported && @imported[:is_local] && @imported[:catalog_id]
                 resource_class.find(@imported[:catalog_id])
               else
                 resolve_catalog_resource(attributes)
               end
    resource.importing_metadata = true if @imported
    resource
  end

  def record_import_baseline
    return unless @imported && @resource.previously_new_record?

    MetadataRefresh.find_or_create_by!(item: @resource).update!(
      provider_values: MetadataImport.attributes(@imported, resource_class).stringify_keys
    )
  end

  def preload_entity_credits
    return unless @resource.respond_to?(:metadata_credits)

    ActiveRecord::Associations::Preloader.new(records: [@resource],
                                              associations: { metadata_credits: :metadata_entity }).call
  end

  def resolve_catalog_resource(attributes)
    key = attributes[:api_id].present? ? :api_id : :title
    resource_class.find_or_initialize_by(key => attributes[key])
  end

  def enqueue_initial_metadata
    return if @resource.is_a?(VideoGame)

    MetadataRefresher.new(@resource, current_user).enqueue if @resource.api_id.present?
  end

  def prepare_child_display
    preload_child_library_items
    render_series_frame if @series_collection && turbo_frame_request_id == 'series-entries'
  end

  def preload_child_library_items
    return unless @resource.is_a?(TvShow) || @resource.is_a?(Comic)

    prepare_series_collection(@resource, @library_item)
  end

  def catalog_scope(scope)
    scope = MetadataSearch.call(scope, params[:q])
    if @personal_library
      query = MediaLibraryQuery.new(resource_class, user: current_user, filters: params)
      @library_statistics = query.statistics
      return query.call(scope)
    end
    scope = filter_catalog_library(scope) if logged_in?
    return scope if params[:q].present? && params[:sort].blank?

    case params[:sort]
    when 'title' then scope.order(title: :asc, id: :asc)
    when 'oldest' then scope.order(created_at: :asc, id: :asc)
    else scope.order(updated_at: :desc, id: :desc)
    end
  end

  def prepare_media_library
    @libraries = current_user.library_items.where(item_type: resource_class.name, item_id: @resources.map(&:id))
                             .includes(:consumption_passes).index_by(&:item_id)
    records = current_user.library_items.where(item_type: resource_class.name)
    @library_formats = records.pluck(:owned_physically_format, :owned_digitally_format).flatten.compact_blank.uniq.sort
    prepare_series_library if %w[TvShow Comic].include?(resource_class.name)
  end

  def prepare_series_library
    child_class, foreign_key = resource_class == TvShow ? [TvEpisode, :tv_show_id] : [ComicIssue, :comic_id]
    pass_ids = @libraries.values.flat_map { |library| library.consumption_passes.map(&:id) }
    @library_pass_counts = ConsumptionPassEntry.where(consumption_pass_id: pass_ids).group(:consumption_pass_id).count
    children = child_class.where(foreign_key => @resources.map(&:id))
    @library_child_totals = children.group(foreign_key).count
    consumed_ids = current_user.library_items.where(item_type: child_class.name, consumed: true).select(:item_id)
    @library_child_consumed = children.where(id: consumed_ids).group(foreign_key).count
  end

  def filter_catalog_library(scope)
    field = { 'collection' => :is_collected, 'backlog' => :in_backlog, 'finished' => :consumed }[params[:status]]
    return scope unless field

    ids = LibraryItem.where(user: current_user, item_type: resource_class.name).where(field => true).select(:item_id)
    scope.where(id: ids)
  end

  def resource_class
    controller_name.classify.constantize
  end

  def resource_name
    controller_name.singularize
  end

  def failure_status
    :unprocessable_content
  end

  def after_library_saved; end

  def resource_params
    raise NotImplementedError
  end
end
