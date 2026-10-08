# frozen_string_literal: true

module Admin
  class SearchController < ApplicationController
    def index
      @query = params[:q].to_s.strip.first(120)
      @results = []
      return if @query.length < 2

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      @results = (Catalog::TYPES + [User]).filter_map do |model|
        columns = search_columns(model)
        predicates = columns.map { |column| "LOWER(#{column}) LIKE LOWER(:pattern) ESCAPE '\\'" }
        scope = model.where(predicates.join(' OR '), pattern: pattern)
        records = Catalog.eager_load(scope).order(updated_at: :desc).limit(8).to_a
        [model, records] if records.any?
      end
    end

    private

    def search_columns(model)
      return %w[name username email] if model == User

      [model == TvEpisode ? 'name' : 'title']
    end
  end
end
