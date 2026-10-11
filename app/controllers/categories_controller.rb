# frozen_string_literal: true

class CategoriesController < ApplicationController
  PAGE_SIZE = 24
  LIST_PAGE_SIZE = 48

  before_action :validate_category_type, only: %i[type_index show]

  def index
    @types = Category::TYPES.keys
    @top_categories = @types.index_with do |type|
      Category.list_for(type, limit: 12)
    end
    @counts = @types.index_with do |type|
      Category.list_for(type).size
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

    @singular = Category.singular_for(@category_type)
    @category_title = Category.title_for(@category_type)

    all_matches = Category.items_for(@category_type, @name)
    @media_counts = {
      'all' => all_matches.size,
      'movies' => all_matches.count { |i| i.is_a?(Movie) },
      'tv_shows' => all_matches.count { |i| i.is_a?(TvShow) },
      'albums' => all_matches.count { |i| i.is_a?(Album) },
      'comics' => all_matches.count { |i| i.is_a?(Comic) },
      'video_games' => all_matches.count { |i| i.is_a?(VideoGame) }
    }

    filtered_matches = Category.items_for(@category_type, @name, media_type: params[:type], sort: params[:sort])
    @items = Kaminari.paginate_array(filtered_matches).page(params[:page]).per(PAGE_SIZE)
  end

  private

  def validate_category_type
    @category_type = params[:category_type].to_s.strip.downcase
    return if Category.valid_type?(@category_type)

    redirect_to categories_path, alert: "Category type '#{params[:category_type]}' not found."
  end
end
