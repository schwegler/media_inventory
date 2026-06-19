# frozen_string_literal: true

class Album < ApplicationRecord
  include LibraryItemFormAttributes

  has_one_attached :cover_image
  has_many :comments, as: :commentable, dependent: :destroy
  validates :title, presence: true
end
