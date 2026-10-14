# frozen_string_literal: true

class AddReviewPublishedAtToLibraryItems < ActiveRecord::Migration[8.1]
  def up
    add_column :library_items, :review_published_at, :datetime
    # Historical publication time is unavailable; use the first review activity, then entry creation.
    execute <<~SQL
      UPDATE library_items SET review_published_at = COALESCE(
        (SELECT MIN(activities.created_at) FROM activities
         WHERE activities.trackable_type = 'LibraryItem'
           AND activities.trackable_id = library_items.id AND activities.activity_type = 'reviewed'), created_at)
      WHERE is_public = 1 AND review IS NOT NULL AND TRIM(review) != ''
    SQL
    add_index :library_items, %i[is_public review_published_at id], name: 'index_library_items_on_public_reviews'
  end

  def down
    remove_column :library_items, :review_published_at
  end
end
