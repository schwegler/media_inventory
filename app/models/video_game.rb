# frozen_string_literal: true

class VideoGame < ApplicationRecord
  include Trackable

  belongs_to :user, optional: true
  has_one_attached :cover_image
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true
  validates :api_id, uniqueness: { scope: :user_id }, allow_blank: true
  validates :title, uniqueness: { scope: %i[user_id platform], case_sensitive: false }, if: -> { api_id.blank? }
end
