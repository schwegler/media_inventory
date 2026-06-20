# frozen_string_literal: true

module Admin
  module MediaActions
    extend ActiveSupport::Concern

    included do
      # Make sure Administrate exposes these actions in the UI
      # We'll need to override Administrate views or add links, but having them here allows the routes to work.
    end

    def merge
      @source_item = requested_resource
      @target_items = requested_resource.class.where.not(id: @source_item.id).order(:title)
      render 'admin/application/merge'
    end

    # rubocop:disable Metrics/AbcSize
    def do_merge
      @source_item = requested_resource
      @target_item = requested_resource.class.find(params[:target_id])

      ActiveRecord::Base.transaction do
        # Move all relationships
        LibraryItem.where(item: @source_item).update_all(item_id: @target_item.id)

        # Migrate Activities (polymorphic trackable)
        Activity.where(trackable_type: @source_item.class.name, trackable_id: @source_item.id)
                .update_all(trackable_id: @target_item.id)

        # Migrate Comments (polymorphic commentable)
        Comment.where(commentable_type: @source_item.class.name, commentable_id: @source_item.id)
               .update_all(commentable_id: @target_item.id)

        # Migrate Likes (polymorphic likeable)
        # Avoid duplicate likes from the same user
        Like.where(likeable_type: @source_item.class.name, likeable_id: @source_item.id).each do |like|
          if Like.exists?(user_id: like.user_id, likeable_type: @target_item.class.name, likeable_id: @target_item.id)
            like.destroy
          else
            like.update(likeable_id: @target_item.id)
          end
        end

        # Destroy the duplicate
        @source_item.destroy!
      end

      redirect_to [:admin, @target_item], notice: "#{requested_resource.class.model_name.human} was successfully merged."
    end
    # rubocop:enable Metrics/AbcSize

    def search_api
      @item = requested_resource
      @query = params[:query] || @item.title

      @results = if @query.present?
                   MediaSearchService.call(@query, @item.class.name.underscore)
                 else
                   []
                 end

      render 'admin/application/search_api'
    end

    def update_from_api
      @item = requested_resource

      api_data = params.require(:api_data).permit(
        :title, :director, :artist, :writer, :publisher, :developer,
        :platform, :release_year, :genre, :network, :api_id,
        :external_url, :thumbnail_url
      )

      api_data.to_h.each do |key, value|
        next if value.blank?

        @item.send("#{key}=", value) if @item.respond_to?("#{key}=") && @item.send(key).blank?
      end

      if @item.save
        redirect_to [:admin, @item], notice: 'Item successfully updated from API data.'
      else
        redirect_to [:admin, @item], alert: 'Failed to update item from API data.'
      end
    end
  end
end
