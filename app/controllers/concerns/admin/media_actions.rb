# frozen_string_literal: true

module Admin
  module MediaActions
    extend ActiveSupport::Concern

    def merge
      @source_item = requested_resource
      @target_items = @source_item.class.where.not(id: @source_item.id).order(:title)
      render 'admin/application/merge'
    end

    def do_merge
      source = requested_resource
      target = source.class.find(params[:target_id])
      MergeMedia.call(source, target)
      redirect_to [:admin, target], notice: "#{source.class.model_name.human} was successfully merged.", status: :see_other
    rescue MergeMedia::Conflict => e
      redirect_to [:merge, :admin, source], alert: e.message, status: :see_other
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotDestroyed
      redirect_to [:merge, :admin, source], alert: 'The merge could not be saved. Review both records and try again.',
                                            status: :see_other
    end

    def search_api
      @item = requested_resource
      @query = (params[:query] || @item.title).to_s.first(120)
      @results = @query.present? ? MediaSearchService.call(@query, @item.class.name.underscore) : []
      render 'admin/application/search_api'
    end

    def update_from_api
      @item = requested_resource
      api_data = params.require(:api_data).permit(
        :title, :director, :artist, :author, :writer, :publisher, :developer,
        :platform, :release_year, :genre, :network, :api_id, :external_url, :thumbnail_url
      )
      api_data.each do |key, value|
        @item.public_send("#{key}=", value) if value.present? && @item.has_attribute?(key) && @item.public_send(key).blank?
      end
      changed = @item.changed?
      if @item.save
        message = if changed
                    'Item successfully updated from API data.'
                  else
                    'No empty fields to fill. Existing metadata was preserved.'
                  end
        redirect_to [:admin, @item], notice: message, status: :see_other
      else
        redirect_to [:admin, @item], alert: 'Failed to update item from API data. Review the field values and try again.',
                                     status: :see_other
      end
    end
  end
end
