# frozen_string_literal: true

class EnrichVideoGameJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(game)
    adapter = MetadataProvider.new(game, include_children: false)
    fields, = adapter.call
    game.with_lock do
      refresh = MetadataRefresh.find_by(item: game) || MetadataRefresh.create_or_find_by!(item: game)
      values = assign_missing_fields(game, fields, refresh)
      game.save! if game.changed?
      refresh.update!(provider: adapter.provider, provider_values: refresh.provider_values.merge(values),
                      state: values.any? ? 'success' : 'unchanged', requested_at: Time.current,
                      succeeded_at: Time.current)
    end
  rescue MetadataProvider::Unavailable, MetadataProvider::RateLimited, MetadataProvider::Unsupported
    Rails.logger.info "Game enrichment unavailable for VideoGame##{game.id}"
    refresh = MetadataRefresh.find_by(item: game) || MetadataRefresh.create_or_find_by!(item: game)
    refresh.update!(state: 'unavailable', requested_at: Time.current)
  end

  private

  def assign_missing_fields(game, fields, refresh)
    fields.compact_blank.each_with_object({}) do |(field, value), values|
      next unless eligible_field?(game, field, refresh)
      next unless game.public_send(field).blank? || (field == :game_type && game.game_type == 'unknown')

      if field == :metadata_credits_data
        value = MetadataEntitySync.without_corrected_roles(game, value,
                                                           Array(refresh.provider_values['corrected_fields']),
                                                           Array(refresh.provider_values['corrected_detail_fields']))
      end
      game.public_send("#{field}=", value)
      values[field.to_s] = value
    end
  end

  def eligible_field?(game, field, refresh)
    game.has_attribute?(field) && !Array(refresh.provider_values['corrected_fields']).include?(field.to_s) &&
      !(field == :thumbnail_url && game.cover_image.attached?)
  end
end
