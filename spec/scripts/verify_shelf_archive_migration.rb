# frozen_string_literal: true

# Run after verify_shelf_display_migration.rb in the same disposable database.
connection = ApplicationRecord.connection
unless Rails.env.test? && connection.adapter_name == 'SQLite' &&
       connection.pool.db_config.database.start_with?('/tmp/trove-shelf-migration-')
  abort 'Use a dedicated /tmp/trove-shelf-migration-* SQLite test database.'
end
require Rails.root.join('db/migrate/20261026210000_add_archive_to_shelf_collections')
migration = AddArchiveToShelfCollections.new
before = ShelfCollection.order(:id).map { |shelf| shelf.attributes.except('archived_at') }
favorites = FavoriteShelf.order(:id).map(&:attributes)
2.times do
  migration.migrate(:down)
  migration.migrate(:up)
  ShelfCollection.reset_column_information
  raise 'Archive default changed access' unless ShelfCollection.where.not(archived_at: nil).none?

  actual = ShelfCollection.order(:id).map { |row| row.attributes.except('archived_at') }
  raise 'Existing shelf content changed' unless actual == before
  raise 'Favorites changed' unless FavoriteShelf.order(:id).map(&:attributes) == favorites
end
shelf = ShelfCollection.first!
shelf.update_column(:archived_at, Time.current)
begin
  migration.migrate(:down)
  raise 'Unsafe rollback accepted'
rescue ActiveRecord::IrreversibleMigration
  raise 'Rollback lost protection' unless connection.column_exists?(:shelf_collections, :archived_at)
end
shelf.update_column(:archived_at, nil)
raise 'Restore changed content' unless ShelfCollection.order(:id).map { |s| s.attributes.except('archived_at') } == before

puts 'PASS: active defaults, two archive roundtrips, exact preservation, guarded archived rollback.'
