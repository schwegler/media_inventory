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
    @resource = resource_class.new(resource_params)
    @resource.user = current_user
    instance_variable_set("@#{resource_name}", @resource)

    respond_to do |format|
      if @resource.save
        format.html { redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully created." }
      else
        format.html { render :new, status: failure_status }
      end
    end
  end

  def show
    @resource = resource_class.find(params[:id])
    unless @resource.is_public || @resource.user == current_user
      redirect_to root_path, alert: 'Not authorized'
      return
    end
    instance_variable_set("@#{resource_name}", @resource)
  end

  def edit
    @resource = resource_class.find(params[:id])
    redirect_to root_path, alert: 'Not authorized' unless @resource.user == current_user
    instance_variable_set("@#{resource_name}", @resource)
  end

  def update
    @resource = resource_class.find(params[:id])
    if @resource.user == current_user
      if @resource.update(resource_params)
        respond_to do |format|
          format.html { redirect_to @resource, notice: "#{resource_class.model_name.human} was successfully updated." }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: failure_status }
        end
      end
    else
      redirect_to root_path, alert: 'Not authorized'
    end
  end

  def destroy
    @resource = resource_class.find(params[:id])
    if @resource.user == current_user
      @resource.destroy
      respond_to do |format|
        format.html do
          redirect_to send("#{resource_name.pluralize}_path"),
                      notice: "#{resource_class.model_name.human} was successfully deleted.",
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
