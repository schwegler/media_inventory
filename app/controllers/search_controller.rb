# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]
    @filter_type = params[:type]

    if @query.present?
      @results = {}
      
      search_term = "%#{@query}%"
      
      if @filter_type.blank? || @filter_type == 'movies'
        @results[:movies] = Movie.where("title LIKE ?", search_term).limit(20)
      end
      
      if @filter_type.blank? || @filter_type == 'albums'
        @results[:albums] = Album.where("title LIKE ?", search_term).limit(20)
      end
      
      if @filter_type.blank? || @filter_type == 'comics'
        @results[:comics] = Comic.where("title LIKE ?", search_term).limit(20)
      end
      
      if @filter_type.blank? || @filter_type == 'tv_shows'
        @results[:tv_shows] = TvShow.where("title LIKE ?", search_term).limit(20)
      end
      
      if @filter_type.blank? || @filter_type == 'video_games'
        @results[:video_games] = VideoGame.where("title LIKE ?", search_term).limit(20)
      end
    else
      @results = {}
    end
  end
end
