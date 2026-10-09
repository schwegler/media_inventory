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
    { source_name: 'tvmaze', media_type: 'TvShow', is_active: true, access_token: '', base_url: 'https://api.tvmaze.com' },
    { source_name: 'SteamGridDB', media_type: 'VideoGame', is_active: false, access_token: '',
      base_url: 'https://www.steamgriddb.com/api/v2' },
    { source_name: 'SteamWebAPI', media_type: 'VideoGame', is_active: false, access_token: '',
      base_url: 'https://api.steampowered.com' },
    { source_name: 'Steam', media_type: 'VideoGame', is_active: true, base_url: 'https://store.steampowered.com/api' },
    { source_name: 'MusicBrainz', media_type: 'Album', is_active: true, base_url: 'https://musicbrainz.org/ws/2' },
    { source_name: 'itunes', media_type: 'Book', is_active: true, base_url: 'https://itunes.apple.com' },
    { source_name: 'OpenLibrary', media_type: 'Book', is_active: true, base_url: 'https://openlibrary.org' },
    { source_name: 'OpenLibrary', media_type: 'Comic', is_active: true, base_url: 'https://openlibrary.org' },
    *%w[Movie TvShow Album VideoGame Comic Book].map do |type|
      { source_name: 'Wikipedia', media_type: type, is_active: true, base_url: 'https://en.wikipedia.org/w/api.php' }
    end,
    *%w[Movie TvShow Album VideoGame Comic Book].map do |type|
      { source_name: 'InternetArchive', media_type: type, is_active: true, base_url: 'https://archive.org' }
    end
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
