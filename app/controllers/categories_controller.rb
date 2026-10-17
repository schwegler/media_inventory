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
      list = Rails.cache.fetch(['category-hub-v2', type], expires_in: 1.minute) do
        CategoryQuery.new(type).categories(per: 12)
      end
      @counts[type] = list.total_count
      @top_categories[type] = list.to_a
    end
  end

  def type_index
    @title = Category.title_for(@category_type)
    @singular = Category.singular_for(@category_type)
    @query = params[:q].to_s.strip
    @sort = params[:sort] || 'count'

    @categories = CategoryQuery.new(@category_type).categories(query: @query, sort: @sort,
                                                               page: params[:page], per: LIST_PAGE_SIZE)
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

    query = CategoryQuery.new(@category_type)
    @items = query.items(@name, media_type: params[:type], sort: params[:sort], page: params[:page], per: PAGE_SIZE)
    @media_counts = query.media_counts
    preload_card_ratings(@items.to_a)
  end

  private

  def validate_category_type
    @category_type = params[:category_type].to_s.strip.downcase
    return if Category.valid_type?(@category_type)

    redirect_to categories_path, alert: "Category type '#{params[:category_type]}' not found."
  end
end
