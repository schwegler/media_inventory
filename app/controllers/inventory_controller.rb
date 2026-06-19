# frozen_string_literal: true

class InventoryController < ApplicationController
  before_action :logged_in_user, only: %i[new create]

  def index
    @resources = resource_class.page(params[:page])
    instance_variable_set("@#{resource_name.pluralize}", @resources)
  end

  def new
    @resource = resource_class.new
    instance_variable_set("@#{resource_name}", @resource)
  end

  def create
    global_params = resource_params.except(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public)
    library_params = resource_params.slice(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public)

    # Handle the transition from watchlist to backlog
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    @resource = if global_params[:api_id].present?
                  resource_class.find_or_initialize_by(api_id: global_params[:api_id])
                else
                  resource_class.find_or_initialize_by(title: global_params[:title])
                end

    @resource.assign_attributes(global_params)
    instance_variable_set("@#{resource_name}", @resource)

    ActiveRecord::Base.transaction do
      if @resource.save
        @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @resource)
        @library_item.assign_attributes(library_params)
        @library_item.save!

        respond_to do |format|
          format.html { redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully logged." }
        end
      else
        respond_to do |format|
          format.html { render :new, status: failure_status }
        end
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

    instance_variable_set("@#{resource_name}", @resource)
  end

  def update
    @resource = resource_class.find(params[:id])
    @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @resource)

    global_params = resource_params.except(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public)
    library_params = resource_params.slice(:is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed,
                                           :consumed_at, :is_public)
    library_params[:in_backlog] = library_params.delete(:in_watchlist) if library_params.key?(:in_watchlist)

    ActiveRecord::Base.transaction do
      @resource.update!(global_params) if global_params.to_h.any?
      @library_item.update!(library_params)
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
