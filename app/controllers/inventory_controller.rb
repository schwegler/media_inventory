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
    instance_variable_set("@#{resource_name}", @resource)
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
