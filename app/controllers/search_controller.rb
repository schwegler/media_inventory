# frozen_string_literal: true

class SearchController < ApplicationController
  MAPPINGS = {
    'movies' => [:movies, Movie],
    'albums' => [:albums, Album],
    'comics' => [:comics, Comic],
    'tv_shows' => [:tv_shows, TvShow],
    'video_games' => [:video_games, VideoGame],
    'books' => [:books, Book]
  }.freeze

  def index
    @query = params[:q]
    @filter_type = params[:type]
    @results = {}

    return if @query.blank?

    load_entities
    @match_context = {}

    MAPPINGS.each do |key, (res_key, klass)|
      next unless @filter_type.blank? || @filter_type == key

      scope = MetadataSearch.call(klass.all, @query)
      scope = scope.with_attached_cover_image if klass.respond_to?(:with_attached_cover_image)
      if klass.respond_to?(:reflect_on_association) && klass.reflect_on_association(:library_items)
        scope = scope.includes(:library_items)
      end
      @results[res_key] = scope.limit(20).to_a
      @match_context[klass.name] = MetadataMatchContext.call(@results[res_key], @query)
    end
  end

  private

  def load_entities
    entity_credits = MetadataCredit.all
    types = { 'albums' => %w[Album AlbumTrack], 'comics' => %w[Comic ComicIssue],
              'tv_shows' => %w[TvShow TvEpisode], 'movies' => ['Movie'],
              'books' => ['Book'], 'video_games' => ['VideoGame'] }
    entity_credits = entity_credits.where(item_type: types[@filter_type]) if types.key?(@filter_type)
    @entities = MetadataEntity.matching(@query).where(id: entity_credits.select(:metadata_entity_id)).limit(12)
  end
end
