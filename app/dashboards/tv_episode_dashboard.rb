# frozen_string_literal: true

require 'administrate/base_dashboard'

class TvEpisodeDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    air_date: Field::String,
    comments: Field::HasMany,
    episode: Field::Number,
    likes: Field::HasMany,
    name: Field::String,
    rating: Field::String,
    review: Field::Text,
    season: Field::Number,
    summary: Field::Text,
    thumbnail_url: Field::String,
    tv_show: Field::BelongsTo,
    watched: Field::Boolean,
    watched_at: Field::Date,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    name
    air_date
    comments
    episode
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    air_date
    comments
    episode
    likes
    name
    rating
    review
    season
    summary
    thumbnail_url
    tv_show
    watched
    watched_at
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    air_date
    comments
    episode
    likes
    name
    rating
    review
    season
    summary
    thumbnail_url
    tv_show
    watched
    watched_at
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how tv episodes are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(tv_episode)
    tv_episode.name
  end
end
