# frozen_string_literal: true

# Reuses signed catalog search selections; never creates a personal library entry.
class ShelfCatalogItemsController < ApplicationController
  before_action :logged_in_user

  def create
    type = params[:type].to_s
    return head :unprocessable_content unless MetadataImport::TYPES.include?(type)

    data = MetadataImport.read(params[:selection], type)
    klass = type.camelize.constantize
    item = resolve_item(klass, data)
    item.importing_metadata = true if item.respond_to?(:importing_metadata=)
    item.save! if item.new_record?
    render json: helpers.shelf_pick_data([item]).first
  rescue MetadataImport::Invalid, GameCatalogIdentity::Invalid, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  def resolve_item(klass, data)
    return klass.find(data[:catalog_id]) if data[:is_local]

    attributes = MetadataImport.attributes(data, klass)
    return GameCatalogIdentity.resolve(attributes) if klass == VideoGame

    # Provider-signed IDs, rather than similar titles, identify existing records.
    existing = klass.find_by(api_id: attributes[:api_id]) if attributes[:api_id].present?
    existing || klass.new(attributes)
  end
end
