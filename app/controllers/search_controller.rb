# frozen_string_literal: true

class SearchController < ApplicationController
  include RecordPreloader

  MAPPINGS = {
    'movies' => [:movies, Movie],
    'albums' => [:albums, Album],
    'comics' => [:comics, Comic],
    'tv_shows' => [:tv_shows, TvShow],
    'video_games' => [:video_games, VideoGame],
    'books' => [:books, Book]
  }.freeze

  def index
    response.headers['Cache-Control'] = 'private, no-store' if logged_in?
    @library_membership = {}
    @query = params[:q]
    @filter_type = params[:type].presence if MAPPINGS.key?(params[:type])
    @results = {}

    return if @query.blank?

    load_entities
    @match_context = {}

    @result_counts = {}
    MAPPINGS.each { |key, (result_key, klass)| load_media_results(key, result_key, klass) }
  end

  private

  def load_media_results(key, result_key, klass)
    return unless @filter_type.blank? || @filter_type == key

    scope = MetadataSearch.call(klass.all, @query)
    scope = scope.with_attached_cover_image if klass.respond_to?(:with_attached_cover_image)
    page_num = @filter_type ? params[:page] : 1
    per_page = 20
    results = scope.order(:title, :id).page(page_num).per(per_page)

    # OPTIMIZATION: Load records array first to determine total count without executing a separate COUNT(*) SQL query
    # when the number of returned records is less than the page limit.
    records = results.to_a
    @result_counts[result_key] = if records.size < per_page && page_num.to_i <= 1
                                   records.size
                                 else
                                   results.total_count
                                 end
    @results[result_key] = results
    if logged_in?
      @library_membership[klass.name] = current_user.library_items.where(item_type: klass.name, item_id: records.map(&:id))
                                                    .pluck(:item_id)
    end
    preload_card_ratings(records)
    @match_context[klass.name] = MetadataMatchContext.call(records, @query)
  end

  def load_entities
    entity_credits = MetadataCredit.all
    types = { 'albums' => %w[Album AlbumTrack], 'comics' => %w[Comic ComicIssue],
              'tv_shows' => %w[TvShow TvEpisode], 'movies' => ['Movie'],
              'books' => ['Book'], 'video_games' => ['VideoGame'] }
    entity_credits = entity_credits.where(item_type: types[@filter_type]) if types.key?(@filter_type)
    @entities = MetadataEntity.matching(@query).where(id: entity_credits.select(:metadata_entity_id)).limit(12)
  end
end
