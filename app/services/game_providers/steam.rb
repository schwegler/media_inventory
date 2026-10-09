# frozen_string_literal: true

module GameProviders
  class Steam < Base
    def name
      'Steam'
    end

    def search(query)
      data = json('https://store.steampowered.com/api/storesearch/', term: query, l: 'english', cc: 'US')
      Array(data['items']).first(5).filter_map do |item|
        next unless item.is_a?(Hash) && item['id'].to_s.match?(/\A\d+\z/) && item['name'].present?

        { title: item['name'], platform: platforms(item['platforms']), thumbnail_url: item['tiny_image'],
          api_id: "steam_#{item['id']}", external_url: "https://store.steampowered.com/app/#{item['id']}", is_local: false }
      end
    end

    def details(id)
      raise Unavailable unless id.to_s.match?(/\A\d+\z/)

      result = json('https://store.steampowered.com/api/appdetails', appids: id.to_s)[id.to_s]
      raise Unavailable unless result.is_a?(Hash) && result['success'] && result['data'].is_a?(Hash)

      data = result['data']
      { developer: Array(data['developers']).join(', ').presence, publisher: Array(data['publishers']).join(', ').presence,
        platform: platforms(data['platforms']), release_year: data.dig('release_date', 'date').to_s[/\b(?:19|20)\d{2}\b/],
        thumbnail_url: data['header_image'].presence || data['capsule_image'].presence,
        game_type: data['type'] == 'music' ? 'soundtrack' : data['type'],
        synopsis: ActionController::Base.helpers.strip_tags(data['short_description'].to_s).presence,
        metadata_details: metadata_details(data) }
    end

    def artwork(id)
      details(id).slice(:thumbnail_url)
    end

    private

    def metadata_details(data)
      {
        'genres' => Array(data['genres']).filter_map { |genre| genre['description'] if genre.is_a?(Hash) },
        'features' => Array(data['categories']).filter_map { |feature| feature['description'] if feature.is_a?(Hash) },
        'languages' => ActionController::Base.helpers.strip_tags(data['supported_languages'].to_s).presence,
        'controller_support' => data['controller_support'], 'official_website' => data['website'],
        'related_steam_dlc_ids' => Array(data['dlc']).grep(Integer),
        'release_date_label' => data.dig('release_date', 'date')
      }.compact_blank
    end

    def platforms(values)
      return unless values.is_a?(Hash)

      values.select { |_key, supported| supported == true }.keys.join(', ').presence
    end
  end
end
