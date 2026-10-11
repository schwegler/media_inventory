# frozen_string_literal: true

# An episode or issue completed within a ConsumptionPass.
class ConsumptionPassEntry < ApplicationRecord
  belongs_to :consumption_pass
  belongs_to :item, polymorphic: true

  validates :item_id, uniqueness: { scope: %i[consumption_pass_id item_type] }
end
