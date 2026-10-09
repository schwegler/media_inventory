# frozen_string_literal: true

module GameProviders
  class Rawg < Base
    def name
      'RAWG'
    end

    def enabled?
      super && token.present?
    end

    def search(query)
      data = json('https://api.rawg.io/api/games', search: query, key: token)
      Array(data['results']).first(5).filter_map do |item|
        next unless item.is_a?(Hash) && item['id'].to_s.match?(/\A\d+\z/) && item['name'].present?

        fields(item).merge(title: item['name'], api_id: "rawg_#{item['id']}",
                           external_url: "https://rawg.io/games/#{item['slug']}", is_local: false)
      end
    end

    def details(id)
      raise Unavailable unless id.to_s.match?(/\A\d+\z/)

      fields(json("https://api.rawg.io/api/games/#{id}", key: token))
    end

    def artwork(id)
      details(id).slice(:thumbnail_url)
    end

    private

    def token
      MediaSources::Registry.token(name, 'VideoGame')
    end

    def fields(data)
      { developer: names(data['developers']), publisher: names(data['publishers']),
        platform: names(Array(data['platforms']).filter_map { |entry| entry['platform'] if entry.is_a?(Hash) }),
        release_year: data['released'].to_s[/\A(?:19|20)\d{2}/], thumbnail_url: data['background_image'],
        synopsis: data['description_raw'].presence,
        metadata_details: {
          'genres' => Array(data['genres']).filter_map { |genre| genre['name'] if genre.is_a?(Hash) },
          'tags' => Array(data['tags']).filter_map { |tag| tag['name'] if tag.is_a?(Hash) },
          'official_website' => data['website'], 'original_release_date' => data['released']
        }.compact_blank }
    end

    def names(rows)
      Array(rows).filter_map { |row| row['name'] if row.is_a?(Hash) }.join(', ').presence
    end
  end
end
