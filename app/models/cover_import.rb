# frozen_string_literal: true

class CoverImport < ApplicationRecord
  belongs_to :item, polymorphic: true
  validates :state, inclusion: { in: %w[pending processing ready failed] }
end
