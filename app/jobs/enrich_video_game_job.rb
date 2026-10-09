# frozen_string_literal: true

class EnrichVideoGameJob < ApplicationJob
  queue_as :media_imports
  discard_on ActiveJob::DeserializationError, ActiveRecord::RecordNotFound

  def perform(game)
    adapter = MetadataProvider.new(game, include_children: false)
    fields, = adapter.call
    game.with_lock do
      values = {}
      fields.compact_blank.each do |field, value|
        next unless game.has_attribute?(field)
        next unless game.public_send(field).blank? || (field == :game_type && game.game_type == 'unknown')

        game.public_send("#{field}=", value)
        values[field.to_s] = value
      end
      game.save! if game.changed?
      refresh = MetadataRefresh.create_or_find_by!(item: game)
      refresh.update!(provider: adapter.provider, provider_values: refresh.provider_values.merge(values),
                      state: values.any? ? 'success' : 'unchanged', requested_at: Time.current,
                      succeeded_at: Time.current)
    end
  rescue MetadataProvider::Unavailable, MetadataProvider::RateLimited, MetadataProvider::Unsupported
    Rails.logger.info "Game enrichment unavailable for VideoGame##{game.id}"
    MetadataRefresh.create_or_find_by!(item: game).update!(state: 'unavailable', requested_at: Time.current)
  end
end
