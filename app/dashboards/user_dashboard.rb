# frozen_string_literal: true

require 'administrate/base_dashboard'

# rubocop:disable Metrics/ClassLength
class UserDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    active_relationships: Field::HasMany,
    activities: Field::HasMany,
    admin: Field::Boolean,
    avatar_url: Field::String,
    bio: Field::Text,
    birthday: Field::Date,
    bsky_access_token: Field::String,
    bsky_app_password: Field::String,
    bsky_custom_message: Field::Text,
    bsky_did: Field::String,
    bsky_handle: Field::String,
    bsky_message_activity_template: Field::String,
    bsky_message_review_template: Field::String,
    bsky_password: Field::String,
    bsky_post_activity: Field::Boolean,
    bsky_post_reviews: Field::Boolean,
    bsky_post_reviews_only: Field::Boolean,
    bsky_refresh_token: Field::String,
    comments: Field::HasMany,
    confirmed_at: Field::DateTime,
    email: Field::String,
    followers: Field::HasMany,
    following: Field::HasMany,
    library_items: Field::HasMany,
    likes: Field::HasMany,
    mastodon_access_token: Field::String,
    mastodon_message_activity_template: Field::String,
    mastodon_message_review_template: Field::String,
    mastodon_post_activity: Field::Boolean,
    mastodon_post_reviews: Field::Boolean,
    mastodon_refresh_token: Field::String,
    mastodon_server: Field::String,
    mastodon_uid: Field::String,
    name: Field::String,
    notify_email_comments: Field::Boolean,
    notify_email_follows: Field::Boolean,
    notify_email_likes: Field::Boolean,
    notify_email_posts: Field::Boolean,
    notify_push_comments: Field::Boolean,
    notify_push_follows: Field::Boolean,
    notify_push_likes: Field::Boolean,
    notify_push_posts: Field::Boolean,
    passive_relationships: Field::HasMany,
    password_digest: Field::String,
    private_key: Field::Text,
    public_key: Field::Text,
    theme: Field::String,
    username: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    username
    active_relationships
    activities
    admin
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    active_relationships
    activities
    admin
    avatar_url
    bio
    birthday
    bsky_access_token
    bsky_app_password
    bsky_custom_message
    bsky_did
    bsky_handle
    bsky_message_activity_template
    bsky_message_review_template
    bsky_password
    bsky_post_activity
    bsky_post_reviews
    bsky_post_reviews_only
    bsky_refresh_token
    comments
    confirmed_at
    email
    followers
    following
    library_items
    likes
    mastodon_access_token
    mastodon_message_activity_template
    mastodon_message_review_template
    mastodon_post_activity
    mastodon_post_reviews
    mastodon_refresh_token
    mastodon_server
    mastodon_uid
    name
    notify_email_comments
    notify_email_follows
    notify_email_likes
    notify_email_posts
    notify_push_comments
    notify_push_follows
    notify_push_likes
    notify_push_posts
    passive_relationships
    password_digest
    private_key
    public_key
    theme
    username
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    active_relationships
    activities
    admin
    avatar_url
    bio
    birthday
    bsky_access_token
    bsky_app_password
    bsky_custom_message
    bsky_did
    bsky_handle
    bsky_message_activity_template
    bsky_message_review_template
    bsky_password
    bsky_post_activity
    bsky_post_reviews
    bsky_post_reviews_only
    bsky_refresh_token
    comments
    confirmed_at
    email
    followers
    following
    library_items
    likes
    mastodon_access_token
    mastodon_message_activity_template
    mastodon_message_review_template
    mastodon_post_activity
    mastodon_post_reviews
    mastodon_refresh_token
    mastodon_server
    mastodon_uid
    name
    notify_email_comments
    notify_email_follows
    notify_email_likes
    notify_email_posts
    notify_push_comments
    notify_push_follows
    notify_push_likes
    notify_push_posts
    passive_relationships
    password_digest
    private_key
    public_key
    theme
    username
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

  # Overwrite this method to customize how users are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(user)
    user.username
  end
end
# rubocop:enable Metrics/ClassLength
