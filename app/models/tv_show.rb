# frozen_string_literal: true

class TvShow < ApplicationRecord
  include Trackable

  belongs_to :user, optional: true
  has_one_attached :cover_image
  validates :title, presence: true
end
