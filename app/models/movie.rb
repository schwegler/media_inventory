# frozen_string_literal: true

class Movie < ApplicationRecord
  include HasMetadataEntities
  include ReadableCatalogUrl
  include LibraryItemFormAttributes

  include StoredMediaCover

  has_one :metadata_refresh, as: :item, dependent: :destroy
  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :edit_suggestions, as: :suggestable, dependent: :destroy
  has_many :library_items, as: :item, dependent: :destroy
  validates :title, presence: true

  after_commit :sync_details_from_api, on: %i[create update]

  private

  def sync_details_from_api
    return if importing_metadata

    return if api_id.blank? || !api_id.match?(/\A\d+\z/) || !saved_change_to_api_id?

    api_key = MediaSources::Registry.token('TMDB', 'Movie')
    if api_key.blank?
      Rails.logger.warn 'TMDB API key not configured.'
      return
    end

    data = fetch_tmdb_movie_data(api_key)
    return unless data.is_a?(Hash)

    apply_tmdb_movie_attributes(data)
  rescue StandardError => e
    Rails.logger.error "Failed to sync Movie details: #{e.class}"
  end

  def fetch_tmdb_movie_data(api_key)
    url = URI("https://api.themoviedb.org/3/movie/#{api_id}?api_key=#{api_key}&append_to_response=credits")
    response = MediaSources::Http.get(url)
    JSON.parse(response)
  end

  def apply_tmdb_movie_attributes(data)
    directors, writers, actors_list = extract_tmdb_credits(
      Array(data.dig('credits', 'crew')),
      Array(data.dig('credits', 'cast'))
    )
    genre_names = Array(data['genres']).filter_map { |g| g['name'] }.join(', ').presence
    poster = data['poster_path'] ? "https://image.tmdb.org/t/p/w500#{data['poster_path']}" : thumbnail_url
    year = data['release_date'] ? data['release_date'].split('-').first : release_year

    update!(
      metadata_credits_data: ProviderEntityMetadata.tmdb(data),
      title: data['title'] || title,
      release_year: year,
      director: directors || director,
      writer: writers || writer,
      actors: actors_list || actors,
      genre: genre_names || genre,
      thumbnail_url: poster
    )
  end

  def extract_tmdb_credits(crew, cast)
    directors = crew.select { |p| p['job'] == 'Director' }.map { |p| p['name'] }.compact.uniq.join(', ').presence
    writing = crew.select do |p|
      p['department'] == 'Writing' || %w[Writer Screenplay Story Author].include?(p['job'])
    end
    writers = writing.map { |p| p['name'] }.compact.uniq.first(5).join(', ').presence
    actors_list = cast.slice(0, 10).map { |c| c['name'] }.compact.uniq.join(', ').presence
    [directors, writers, actors_list]
  end
end
