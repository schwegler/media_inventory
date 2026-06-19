# frozen_string_literal: true

class VideoGame < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true
end
