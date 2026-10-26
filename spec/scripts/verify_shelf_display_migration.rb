# frozen_string_literal: true

# Run only with a disposable, schema-loaded SQLite database:
# RAILS_ENV=test DATABASE_URL=sqlite3:/tmp/trove-shelf-migration-check.sqlite3 \
#   bin/rails runner spec/scripts/verify_shelf_display_migration.rb
connection = ApplicationRecord.connection
unless Rails.env.test? && connection.adapter_name == 'SQLite' &&
       connection.pool.db_config.database.start_with?('/tmp/trove-shelf-migration-')
  abort 'Use a dedicated /tmp/trove-shelf-migration-* SQLite test database.'
end
require Rails.root.join('db/migrate/20261026190000_add_shelf_collection_display_settings')
migration = AddShelfCollectionDisplaySettings.new
migration.migrate(:down)
ShelfCollection.reset_column_information
owner = User.create!(name: 'Existing curator', username: 'existing_curator', email: 'migration@example.com',
                     password: 'password', confirmed_at: Time.current)
media = FavoriteShelf::CATEGORIES.except('overall').keys.map { |type| type.constantize.create!(title: "Existing #{type}") }
picks = media.map { |item| { 'type' => item.class.name, 'id' => item.id } }
FavoriteShelf::CATEGORIES.each_key do |category|
  selected = category == 'overall' ? picks.first(5) : picks.select { |pick| pick['type'] == category }
  owner.favorite_shelves.create!(category: category, picks: selected)
end
[0, 1, 5, 6].each do |count|
  ShelfCollection.insert_all!([{ user_id: owner.id, slug: "existing-#{count}", title: "Existing shelf #{count}",
                                description: 'Existing context', picks: picks.first(count),
                                presentation: { theme: 'halloween', layout: 'reading', texture: 'stars', companion: 'bat' },
                                created_at: 1.year.ago, updated_at: 1.month.ago }])
end
before = ShelfCollection.order(:id).map(&:attributes)
favorites = FavoriteShelf.order(:id).map(&:attributes)
2.times do
  migration.migrate(:up)
  ShelfCollection.reset_column_information
  actual = ShelfCollection.order(:id).map(&:attributes)
  raise 'Existing shelf data changed' unless actual.map { |row| row.except('allowed_media_types', 'preview_length') } == before
  raise 'Incorrect migration defaults' unless actual.all? { |row| row['allowed_media_types'] == [] && row['preview_length'] == 5 }
  raise 'Favorites changed' unless FavoriteShelf.order(:id).map(&:attributes) == favorites
  migration.migrate(:down)
  ShelfCollection.reset_column_information
end
migration.migrate(:up)
ShelfCollection.reset_column_information
rows = Movie.insert_all!(1_000.times.map { |index| { title: "Capacity sample #{index}" } }, returning: %w[id])
large_picks = rows.rows.flatten.map { |id| { 'type' => 'Movie', 'id' => id } }
large = owner.shelf_collections.create!(title: 'At operational capacity', picks: large_picks)
raise 'Capacity lost picks' unless large.reload.picks.size == 1_000 && large.items.size == 1_000
raise 'Over-capacity accepted' if large.update(picks: large_picks + [picks.first])
raise 'Rejected update changed stored picks' unless large.reload.picks.size == 1_000
puts 'PASS: existing 0/1/5/6-title shelves, stable IDs/slugs/context/presentation/timestamps, all seven favorites, defaults, two down/up roundtrips, 1,000-title capacity.'
