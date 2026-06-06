# frozen_string_literal: true

class WrestlingEvent < ApplicationRecord
  include Trackable

  belongs_to :user, optional: true
  validates :title, presence: true
end
