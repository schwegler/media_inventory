# frozen_string_literal: true

class TvShow < ApplicationRecord
  belongs_to :user, optional: true
  validates :title, presence: true
end
