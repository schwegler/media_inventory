# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class InventoryController < ApplicationController
  before_action :logged_in_user, only: %i[new create]

  def index
    @resources = resource_class.order(created_at: :desc).page(params[:page])
    instance_variable_set("@#{resource_name.pluralize}", @resources)
  end

  def new
    @resource = resource_class.new
    instance_variable_set("@#{resource_name}", @resource)
  end

  def create
    global_params = resource_params.except(*library_param_keys)
    library_params = resource_params.slice(*library_param_keys)
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    @resource = find_or_init_resource(global_params)
    @resource.assign_attributes(global_params) if !@resource.persisted? || current_user&.admin?
    instance_variable_set("@#{resource_name}", @resource)

    ActiveRecord::Base.transaction do
      if @resource.save
        save_library_item(@resource, library_params)
        redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully logged."
      else
        render :new, status: failure_status
      end
    end
  end

  def show
    @resource = resource_class.find(params[:id])
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

    global_params = resource_params.except(*library_param_keys)
    library_params = resource_params.slice(*library_param_keys)
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    ActiveRecord::Base.transaction do
      @resource.update!(global_params) if global_params.to_h.any? && current_user&.admin?
      @library_item.update!(library_params)
    end

    redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: failure_status
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

  def library_param_keys
    %i[is_collected in_watchlist in_backlog rating review consumed
       consumed_at is_public owned_physically owned_physically_format
       owned_digitally owned_digitally_format]
  end

  def find_or_init_resource(global_params)
    if global_params[:api_id].present?
      resource_class.find_or_initialize_by(api_id: global_params[:api_id])
    else
      resource_class.find_or_initialize_by(title: global_params[:title])
    end
  end

  def save_library_item(resource, library_params)
    @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: resource)
    @library_item.assign_attributes(library_params)
    @library_item.save!
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

  def resource_params
    raise NotImplementedError
  end
end
# rubocop:enable Metrics/ClassLength
