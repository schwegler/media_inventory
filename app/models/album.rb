# frozen_string_literal: true

class Album < ApplicationRecord
  belongs_to :user, optional: true
  validates :title, presence: true
end
