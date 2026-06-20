# frozen_string_literal: true

require 'administrate/base_dashboard'

class LibraryItemDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    activities: Field::HasMany,
    comments: Field::HasMany,
    consumed: Field::Boolean,
    consumed_at: Field::Date,
    in_backlog: Field::Boolean,
    is_collected: Field::Boolean,
    is_public: Field::Boolean,
    item: Field::Polymorphic,
    likes: Field::HasMany,
    rating: Field::String,
    review: Field::Text,
    user: Field::BelongsTo,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    item_type
    activities
    comments
    consumed
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    activities
    comments
    consumed
    consumed_at
    in_backlog
    is_collected
    is_public
    item
    likes
    rating
    review
    user
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    activities
    comments
    consumed
    consumed_at
    in_backlog
    is_collected
    is_public
    item
    likes
    rating
    review
    user
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

  # Overwrite this method to customize how library items are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(library_item)
    "#{library_item.item_type} #{library_item.item_id}"
  end
end
