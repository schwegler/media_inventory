# frozen_string_literal: true

class MigrateMediaToLibraryItems < ActiveRecord::Migration[8.1]
  def up
    migrate_media(Movie)
    migrate_media(TvShow)
    migrate_media(Album)
    migrate_media(Comic)
    migrate_media(VideoGame)

    remove_columns_from_media(Movie)
    remove_columns_from_media(TvShow)
    remove_columns_from_media(Album)
    remove_columns_from_media(Comic)
    remove_columns_from_media(VideoGame)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def migrate_media(klass)
    records = klass.all
    grouped_records = records.group_by do |r|
      r.api_id.presence || r.title.downcase.strip
    end

    grouped_records.each_value do |group|
      primary_record = group.min_by(&:created_at)

      group.each do |record|
        LibraryItem.create!(
          user_id: record.user_id,
          item_type: klass.name,
          item_id: primary_record.id,
          is_collected: record.respond_to?(:is_collected) ? record.is_collected : false,
          in_backlog: record.respond_to?(:in_watchlist) ? record.in_watchlist : false,
          rating: record.respond_to?(:rating) ? record.rating : nil,
          review: record.respond_to?(:review) ? record.review : nil,
          consumed: record.respond_to?(:consumed) ? record.consumed : false,
          consumed_at: record.respond_to?(:consumed_at) ? record.consumed_at : nil,
          is_public: record.respond_to?(:is_public) ? record.is_public : false
        )

        next unless record.id != primary_record.id

        Activity.where(trackable_type: klass.name, trackable_id: record.id).update_all(trackable_id: primary_record.id)
        Comment.where(commentable_type: klass.name,
                      commentable_id: record.id).update_all(commentable_id: primary_record.id)
        Like.where(likeable_type: klass.name, likeable_id: record.id).update_all(likeable_id: primary_record.id)
        record.destroy
      end
    end
  end

  def remove_columns_from_media(klass)
    table_name = klass.table_name
    remove_column table_name, :user_id if column_exists?(table_name, :user_id)
    remove_column table_name, :is_collected if column_exists?(table_name, :is_collected)
    remove_column table_name, :in_watchlist if column_exists?(table_name, :in_watchlist)
    remove_column table_name, :rating if column_exists?(table_name, :rating)
    remove_column table_name, :review if column_exists?(table_name, :review)
    remove_column table_name, :consumed if column_exists?(table_name, :consumed)
    remove_column table_name, :consumed_at if column_exists?(table_name, :consumed_at)
    remove_column table_name, :is_public if column_exists?(table_name, :is_public)
  end
end
