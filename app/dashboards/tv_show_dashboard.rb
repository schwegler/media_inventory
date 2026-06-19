# frozen_string_literal: true

require 'administrate/base_dashboard'

class TvShowDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    api_id: Field::String,
    comments: Field::HasMany,
    cover_image_attachment: Field::HasOne,
    cover_image_blob: Field::HasOne,
    external_url: Field::String,
    likes: Field::HasMany,
    network: Field::String,
    thumbnail_url: Field::String,
    title: Field::String,
    tv_episodes: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    api_id
    comments
    cover_image_attachment
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    api_id
    comments
    cover_image_attachment
    cover_image_blob
    external_url
    likes
    network
    thumbnail_url
    title
    tv_episodes
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    api_id
    comments
    cover_image_attachment
    cover_image_blob
    external_url
    likes
    network
    thumbnail_url
    title
    tv_episodes
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

  # Overwrite this method to customize how tv shows are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(tv_show)
  #   "TvShow ##{tv_show.id}"
  # end
end
