# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]
    @filter_type = params[:type]
    @results = {}

    return if @query.blank?

    search_term = "%#{@query}%"
    mappings = {
      'movies' => [:movies, Movie],
      'albums' => [:albums, Album],
      'comics' => [:comics, Comic],
      'tv_shows' => [:tv_shows, TvShow],
      'video_games' => [:video_games, VideoGame],
      'books' => [:books, Book]
    }

    mappings.each do |key, (res_key, klass)|
      next unless @filter_type.blank? || @filter_type == key

      scope = klass.where('title LIKE ?', search_term)
      scope = scope.with_attached_cover_image if klass.respond_to?(:with_attached_cover_image)
      if klass.respond_to?(:reflect_on_association) && klass.reflect_on_association(:library_items)
        scope = scope.includes(:library_items)
      end
      @results[res_key] = scope.limit(20)
    end
  end
end
