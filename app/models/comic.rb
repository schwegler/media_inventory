# frozen_string_literal: true

class Comic < ApplicationRecord
  belongs_to :user, optional: true
  validates :title, presence: true
end
