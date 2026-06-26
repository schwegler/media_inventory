# frozen_string_literal: true

module VisibleTo
  extend ActiveSupport::Concern

  included do
    # Filters media items that are visible to the given user.
    # An item is visible if:
    # 1. It is explicitly marked as public in any user's library.
    # 2. It belongs to the current user's library (even if private).
    # 3. It has no library items (it's a global/system item).
    scope :visible_to, lambda { |user|
      return all if user&.admin?

      left_outer_joins(:library_items)
        .where('library_items.id IS NULL OR library_items.is_public = ? OR library_items.user_id = ?', true, user&.id)
        .distinct
    }
  end
end
