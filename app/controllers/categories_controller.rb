# frozen_string_literal: true

class CategoriesController < ApplicationController
  include RecordPreloader

  PAGE_SIZE = 24
  LIST_PAGE_SIZE = 48

  before_action :validate_category_type, only: %i[type_index show]

  def index
    @types = Category::TYPES.keys
    @top_categories = {}
    @counts = {}
    @types.each do |type|
      list = Category.list_for(type)
      @counts[type] = list.size
      @top_categories[type] = list.first(12)
    end
  end

  def type_index
    @title = Category.title_for(@category_type)
    @singular = Category.singular_for(@category_type)
    @query = params[:q].to_s.strip
    @sort = params[:sort] || 'count'

    all_categories = Category.list_for(@category_type, query: @query, sort: @sort)
    @categories = Kaminari.paginate_array(all_categories).page(params[:page]).per(LIST_PAGE_SIZE)
  end

  def show
    @name = params[:name].to_s.strip
    if @name.blank?
      redirect_to category_type_path(category_type: @category_type)
      return
    end

    @canonical_entities = MetadataEntity.where(normalized_name: MetadataEntity.normalize(@name))
    @singular = Category.singular_for(@category_type)
    @category_title = Category.title_for(@category_type)

    all_matches = Category.items_for(@category_type, @name)
    @media_counts = calculate_media_counts(all_matches)

    # Reuse in-memory matches to prevent duplicate database queries
    filtered_matches = filter_and_sort_matches(all_matches)
    @items = Kaminari.paginate_array(filtered_matches).page(params[:page]).per(PAGE_SIZE)
    preload_card_ratings(@items.to_a)
  end

  private

  def calculate_media_counts(matches)
    {
      'all' => matches.size,
      'movies' => matches.count { |i| i.is_a?(Movie) },
      'tv_shows' => matches.count { |i| i.is_a?(TvShow) },
      'albums' => matches.count { |i| i.is_a?(Album) },
      'comics' => matches.count { |i| i.is_a?(Comic) },
      'books' => matches.count { |i| i.is_a?(Book) },
      'video_games' => matches.count { |i| i.is_a?(VideoGame) }
    }
  end

  def filter_and_sort_matches(matches)
    filtered = if params[:type].present?
                 matches.select { |item| Category.media_type_matches?(item.class, params[:type]) }
               else
                 matches
               end
    Category.sort_items(filtered, params[:sort])
  end

  def validate_category_type
    @category_type = params[:category_type].to_s.strip.downcase
    return if Category.valid_type?(@category_type)

    redirect_to categories_path, alert: "Category type '#{params[:category_type]}' not found."
  end
end
