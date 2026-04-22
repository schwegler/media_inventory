# frozen_string_literal: true

class WrestlingEvent < ApplicationRecord
  belongs_to :user, optional: true
  validates :title, presence: true
end
