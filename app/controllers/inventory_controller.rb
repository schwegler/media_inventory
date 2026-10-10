# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class InventoryController < ApplicationController
  # Centralize authentication filter for all mutating inventory actions
  before_action :logged_in_user, only: %i[new create edit update destroy]

  def index
    scope = resource_class
    # Eager load ActiveStorage attachments/blobs for cover images to prevent N+1 queries when rendering media card grids
    scope = scope.with_attached_cover_image if scope.respond_to?(:with_attached_cover_image)

    @resources = catalog_scope(scope).page(params[:page])
    instance_variable_set("@#{resource_name.pluralize}", @resources)
  end

  def new
    @resource = resource_class.new
    instance_variable_set("@#{resource_name}", @resource)
  end

  # rubocop:disable Metrics/MethodLength
  def create
    global_params = resource_params.except(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public, :owned_physically, :owned_physically_format,
                                           :owned_digitally, :owned_digitally_format)
    library_params = resource_params.slice(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public, :owned_physically, :owned_physically_format,
                                           :owned_digitally, :owned_digitally_format)

    # Handle the transition from watchlist to backlog
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    @resource = resolve_catalog_resource(global_params)

    # Logging a shared game must not overwrite another user's curated catalog.
    @resource.assign_attributes(global_params) unless @resource.is_a?(VideoGame) && @resource.persisted?
    instance_variable_set("@#{resource_name}", @resource)

    ActiveRecord::Base.transaction do
      if @resource.save
        @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @resource)
        @library_item.assign_attributes(library_params)
        @library_item.save!
        after_library_saved
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
    end
  end

  def show
    @resource = resource_class.find(params[:id])
    return if redirect_to_canonical_url(@resource)

    if logged_in?
      @library_item = LibraryItem.find_by(user: current_user, item: @resource)
      if @library_item
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
      end
    end
    preload_child_library_items
    instance_variable_set("@#{resource_name}", @resource)
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

    global_params = resource_params.except(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public, :owned_physically, :owned_physically_format,
                                           :owned_digitally, :owned_digitally_format)
    library_params = resource_params.slice(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public, :owned_physically, :owned_physically_format,
                                           :owned_digitally, :owned_digitally_format)
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    ActiveRecord::Base.transaction do
      @resource.update!(global_params) if global_params.to_h.any?
      @library_item.update!(library_params)
      after_library_saved
    end

    respond_to do |format|
      format.html { redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully updated." }
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

  def resolve_catalog_resource(attributes)
    key = attributes[:api_id].present? ? :api_id : :title
    resource_class.find_or_initialize_by(key => attributes[key])
  end

  def enqueue_initial_metadata
    return if @resource.is_a?(VideoGame)

    MetadataRefresher.new(@resource, current_user).enqueue if @resource.api_id.present?
  end

  def preload_child_library_items
    return unless logged_in?

    type, children, variable = case @resource
                               when TvShow then ['TvEpisode', @resource.tv_episodes, :@episode_library_items]
                               when Comic then ['ComicIssue', @resource.comic_issues, :@issue_library_items]
                               else return
                               end
    entries = current_user.library_items.where(item_type: type, item_id: children.select(:id)).index_by(&:item_id)
    instance_variable_set(variable, entries)
  end

  def catalog_scope(scope)
    if params[:q].present?
      query = "%#{resource_class.sanitize_sql_like(params[:q].to_s.strip.downcase, '!')}%"
      scope = scope.where("LOWER(title) LIKE ? ESCAPE '!'", query)
    end
    scope = filter_catalog_library(scope) if logged_in?
    case params[:sort]
    when 'title' then scope.order(title: :asc, id: :asc)
    when 'oldest' then scope.order(created_at: :asc, id: :asc)
    else scope.order(created_at: :desc, id: :desc)
    end
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
# rubocop:enable Metrics/ClassLength
