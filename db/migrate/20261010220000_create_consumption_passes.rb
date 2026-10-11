# frozen_string_literal: true

# A "pass" is one run through a series (a watch of a show, a read of a comic), mirroring
# GamePlaythrough for games. Library items for episodes/issues keep meaning "consumed at
# least once"; passes record what has been done in each individual run.
class CreateConsumptionPasses < ActiveRecord::Migration[8.1]
  class MigrationLibraryItem < ActiveRecord::Base
    self.table_name = 'library_items'
    self.inheritance_column = nil
  end

  def up
    create_table :consumption_passes do |t|
      t.references :library_item, null: false, foreign_key: true
      t.integer :number, null: false, default: 1
      t.string :status, null: false, default: 'active'
      t.date :started_on
      t.date :completed_on
      t.timestamps
    end
    add_index :consumption_passes, %i[library_item_id number], unique: true
    add_index :consumption_passes, :library_item_id, unique: true, where: "status = 'active'",
                                                     name: 'index_consumption_passes_one_active_per_item'

    create_table :consumption_pass_entries do |t|
      t.references :consumption_pass, null: false, foreign_key: true
      t.string :item_type, null: false
      t.integer :item_id, null: false
      t.datetime :consumed_at, null: false
      t.timestamps
    end
    add_index :consumption_pass_entries, %i[consumption_pass_id item_type item_id],
              unique: true, name: 'index_pass_entries_on_pass_and_item'

    backfill('TvShow', 'TvEpisode', 'tv_episodes', 'tv_show_id')
    backfill('Comic', 'ComicIssue', 'comic_issues', 'comic_id')
  end

  def down
    drop_table :consumption_pass_entries
    drop_table :consumption_passes
  end

  private

  # One first pass per series that already has progress. Fully finished series are marked
  # completed so they stay out of the in-progress tracker; partial ones stay active.
  def backfill(series_type, child_type, child_table, foreign_key)
    now = Time.current
    MigrationLibraryItem.where(item_type: series_type).find_each do |series_lib|
      total = select_value("SELECT COUNT(*) FROM #{child_table} WHERE #{foreign_key} = #{series_lib.item_id.to_i}").to_i
      children = MigrationLibraryItem.where(user_id: series_lib.user_id, item_type: child_type, consumed: true)
                                     .where("item_id IN (SELECT id FROM #{child_table} WHERE #{foreign_key} = ?)",
                                            series_lib.item_id)
                                     .to_a
      next if children.empty?

      done = total.positive? && children.size >= total
      pass_id = insert_pass(series_lib.id, done, children, now)
      children.each { |child| insert_entry(pass_id, child_type, child, now) }
    end
  end

  def insert_pass(library_item_id, done, children, now)
    dates = children.filter_map(&:consumed_at)
    insert <<~SQL.squish
      INSERT INTO consumption_passes (library_item_id, number, status, started_on, completed_on, created_at, updated_at)
      VALUES (#{library_item_id.to_i}, 1, #{quote(done ? 'completed' : 'active')}, #{quote(dates.min)},
              #{quote(done ? dates.max : nil)}, #{quote(now)}, #{quote(now)})
    SQL
  end

  def insert_entry(pass_id, child_type, child, now)
    at = child.consumed_at&.to_time || child.updated_at || now
    execute <<~SQL.squish
      INSERT INTO consumption_pass_entries (consumption_pass_id, item_type, item_id, consumed_at, created_at, updated_at)
      VALUES (#{pass_id.to_i}, #{quote(child_type)}, #{child.item_id.to_i}, #{quote(at)}, #{quote(now)}, #{quote(now)})
    SQL
  end
end
