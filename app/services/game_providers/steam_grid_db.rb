# frozen_string_literal: true

module GameProviders
  # Steam app ID lookup is an identity bridge; a title search cannot authorize
  # borrowing artwork. Local storage is explicitly opt-in after rights review.
  class SteamGridDb < Base
    def name
      'SteamGridDB'
    end

    def capabilities
      %i[artwork external_identifiers].freeze
    end

    def enabled?
      config = ApiConfiguration.find_by(source_name: name, media_type: 'VideoGame', is_active: true)
      config && config.access_token.present? && JSON.parse(config.options.presence || '{}')['allow_image_storage'] == true
    rescue JSON::ParserError
      false
    end

    def artwork(steam_id)
      return [] unless enabled? && steam_id.to_s.match?(/\A\d+\z/)

      data = json("https://www.steamgriddb.com/api/v2/grids/steam/#{steam_id}", dimensions: '600x900', types: 'static')
      raise Unavailable unless data['success'] == true && data['data'].is_a?(Array)

      format_candidates(data['data'])
    rescue MediaSources::Http::Error, JSON::ParserError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError, Unavailable
      []
    end

    private

    def request_headers
      config = ApiConfiguration.find_by!(source_name: name, media_type: 'VideoGame', is_active: true)
      { 'Authorization' => "Bearer #{config.access_token}" }
    end

    def format_candidates(rows)
      rows.select { |row| row.is_a?(Hash) && row['width'].to_i == 600 && row['height'].to_i == 900 }
          .sort_by { |row| -row['score'].to_i }.first(3).map do |row|
        { url: row['url'], provider: name, provider_id: row['id'].to_s, artwork_type: 'portrait_cover',
          matched_by: 'steam_app_id', author: row.dig('author', 'name'),
          attribution_url: "https://www.steamgriddb.com/grid/#{row['id']}", storage_eligible: true }
      end
    end
  end
end
