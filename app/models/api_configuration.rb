# frozen_string_literal: true

class ApiConfiguration < ApplicationRecord
  DEFAULT_APIS = [
    { source_name: 'TMDB', media_type: 'Movie', is_active: true, access_token: '',
      base_url: 'https://api.themoviedb.org/3' },
    { source_name: 'TMDB', media_type: 'TvShow', is_active: true, access_token: '',
      base_url: 'https://api.themoviedb.org/3' },
    { source_name: 'RAWG', media_type: 'VideoGame', is_active: true, access_token: '',
      base_url: 'https://api.rawg.io/api' },
    { source_name: 'ComicVine', media_type: 'Comic', is_active: true, access_token: '',
      base_url: 'https://comicvine.gamespot.com/api' },
    { source_name: 'itunes', media_type: 'Movie', is_active: true, access_token: '', base_url: 'https://itunes.apple.com' },
    { source_name: 'itunes', media_type: 'TvShow', is_active: true, access_token: '',
      base_url: 'https://itunes.apple.com' },
    { source_name: 'itunes', media_type: 'Album', is_active: true, access_token: '', base_url: 'https://itunes.apple.com' },
    { source_name: 'tvmaze', media_type: 'TvShow', is_active: true, access_token: '', base_url: 'https://api.tvmaze.com' }
  ].freeze

  def self.seed_defaults!
    DEFAULT_APIS.each do |api|
      find_or_create_by!(source_name: api[:source_name], media_type: api[:media_type]) do |config|
        config.is_active = api[:is_active]
        config.access_token = api[:access_token]
        config.base_url = api[:base_url]
      end
    end
  end
end
