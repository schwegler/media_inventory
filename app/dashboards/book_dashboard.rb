# frozen_string_literal: true

require 'administrate/base_dashboard'

class BookDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    title: Field::String,
    author: Field::String,
    publisher: Field::String,
    release_year: Field::Number,
    api_id: Field::String,
    external_url: Field::String,
    thumbnail_url: Field::String,
    likes: Field::HasMany,
    comments: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    title
    author
    release_year
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    author
    publisher
    release_year
    api_id
    external_url
    thumbnail_url
    likes
    comments
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    title
    author
    publisher
    release_year
    api_id
    external_url
    thumbnail_url
  ].freeze

  def display_resource(book)
    "Book ##{book.id} (#{book.title})"
  end
end
