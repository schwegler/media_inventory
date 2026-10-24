# frozen_string_literal: true

# Keep signed provider payloads out of URLs and cookie sessions.
class DiscoveryIntent
  TTL = 1.hour

  def self.store(type:, selection:, query:)
    MetadataImport.read(selection, type)
    id = SecureRandom.hex(24)
    MediaSources::Registry::CACHE.write(['discovery-intent', id],
                                        { type: type, selection: selection, query: query.to_s.first(200) }, expires_in: TTL)
    id
  end

  def self.read(id)
    return unless id.is_a?(String) && id.match?(/\A[0-9a-f]{48}\z/)

    MediaSources::Registry::CACHE.read(['discovery-intent', id])
  end
end
