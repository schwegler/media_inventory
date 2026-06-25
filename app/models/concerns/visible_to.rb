# frozen_string_literal: true

module VisibleTo
  extend ActiveSupport::Concern

  included do
    scope :visible_to, lambda { |user|
      joins(:library_items)
        .where('library_items.is_public = ? OR library_items.user_id = ?', true, user&.id)
        .distinct
    }
  end
end
