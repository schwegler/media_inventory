# frozen_string_literal: true

module Admin
  # One definition for dashboard metrics, actionable filters, and global search.
  module Catalog
    TYPES = [Movie, TvShow, TvEpisode, VideoGame, Book, Comic, ComicIssue, Album].freeze
    MATCHABLE = [Movie, TvShow, VideoGame, Book, Comic, Album].freeze
    FILTERS = {
      'missing_artwork' => 'Missing artwork', 'missing_id' => 'Missing metadata ID',
      'without_children' => 'Without episodes / issues', 'attention' => 'Needs attention'
    }.freeze

    def self.filters_for(model)
      FILTERS.reject do |key, _label|
        (key == 'missing_id' && !MATCHABLE.include?(model)) ||
          (key == 'without_children' && ![TvShow, Comic].include?(model))
      end
    end

    def self.missing_artwork(model)
      table = model.quoted_table_name
      relation = model.where("#{table}.thumbnail_url IS NULL OR TRIM(#{table}.thumbnail_url) = ''")
      return relation unless model.reflect_on_attachment(:cover_image)

      relation.where.not(id: ActiveStorage::Attachment.where(record_type: model.name,
                                                             name: 'cover_image').select(:record_id))
    end

    def self.missing_id(model)
      model.where("api_id IS NULL OR TRIM(api_id) = ''")
    end

    def self.without_children(model)
      case model.name
      when 'TvShow' then model.where.not(id: TvEpisode.select(:tv_show_id))
      when 'Comic' then model.where.not(id: ComicIssue.select(:comic_id))
      else model.none
      end
    end

    def self.filter(model, value)
      case value
      when 'missing_artwork' then missing_artwork(model)
      when 'missing_id' then MATCHABLE.include?(model) ? missing_id(model) : model.none
      when 'without_children' then without_children(model)
      when 'attention'
        scope = missing_artwork(model)
        scope = scope.or(missing_id(model)) if MATCHABLE.include?(model)
        scope.or(without_children(model))
      else model.all
      end
    end

    def self.eager_load(scope)
      model = scope.klass
      scope = scope.with_attached_cover_image if model.reflect_on_attachment(:cover_image)
      scope = scope.includes(:tv_show) if model == TvEpisode
      scope = scope.includes(:comic) if model == ComicIssue
      scope
    end
  end
end
