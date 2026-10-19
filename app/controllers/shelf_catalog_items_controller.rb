# frozen_string_literal: true

# Reuses signed catalog search selections; never creates a personal library entry.
class ShelfCatalogItemsController < ApplicationController
  before_action :logged_in_user

  def create
    type = params[:type].to_s
    return head :unprocessable_content unless MetadataImport::TYPES.include?(type)

    data = MetadataImport.read(params[:selection], type)
    klass = type.camelize.constantize
    item = ShelfCatalogImport.call(klass, data)
    render json: helpers.shelf_pick_data([item]).first
  rescue MetadataImport::Invalid, GameCatalogIdentity::Invalid, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
