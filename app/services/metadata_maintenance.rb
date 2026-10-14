# frozen_string_literal: true

# Explicit, resumable operations: deployment never invokes provider requests.
class MetadataMaintenance
  def self.models
    all = MetadataEntitySync::FIELDS.keys + %w[ComicIssue TvEpisode AlbumTrack]
    type = ENV.fetch('TYPE', nil)
    raise ArgumentError, 'Unknown TYPE' if type.present? && !all.include?(type)

    (type.present? ? [type] : all).map(&:constantize)
  end

  def self.scope(model)
    records = model.where('id > ?', ENV.fetch('AFTER_ID', '0').to_i)
    records = records.where(id: ENV['ID']) if ENV['ID'].present?
    records.order(:id).limit(ENV.fetch('LIMIT', '100').to_i.clamp(1, 10_000))
  end

  def self.backfill
    models.each do |model|
      scope(model).each do |record|
        record.with_lock { MetadataEntitySync.call(record) }
        puts "#{model.name} id=#{record.id} extracted"
      rescue StandardError => e
        warn "#{model.name} id=#{record.id} failed: #{e.class}"
      end
    end
  end

  def self.enrich
    user = User.find(ENV.fetch('USER_ID'))
    models.select { |model| MetadataEntitySync::FIELDS.key?(model.name) }.each do |model|
      scope(model).each do |record|
        next if record.api_id.blank?

        refresh = MetadataRefresh.find_by(item: record)
        next if ENV['FORCE'] != '1' && refresh&.provider_values&.fetch('entity_metadata_version', nil) == 1

        # Use cached HTTP bodies; retain existing refresher leases and ownership rules.
        interval = [ENV.fetch('INTERVAL', '21').to_f, 21].max
        state = MetadataRefresher.new(record, user, revalidate: ENV['FORCE'] == '1').call
        puts "#{model.name} id=#{record.id} #{state}"
        break if state == 'rate_limited'

        sleep interval
      end
    end
  end
end
