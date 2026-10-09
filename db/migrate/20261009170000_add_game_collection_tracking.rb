# frozen_string_literal: true

class AddGameCollectionTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :video_games, :game_type, :string, default: 'unknown', null: false
    create_table :game_external_ids do |t|
      t.references :video_game, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :external_id, null: false
      t.timestamps
    end
    add_index :game_external_ids, %i[provider external_id], unique: true
    create_copies
    create_playthroughs
    create_sessions
    create_journals
  end

  def create_copies
    create_table :game_copies do |t|
      t.references :library_item, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :storefront
      t.string :edition
      t.string :ownership_status, default: 'owned', null: false
      t.string :access_method, default: 'digital', null: false
      t.date :purchase_date
      t.decimal :purchase_price, precision: 12, scale: 2
      t.string :currency
      t.text :notes
      t.timestamps
    end
  end

  def create_playthroughs
    create_table :game_playthroughs do |t|
      t.references :library_item, null: false, foreign_key: true
      t.string :platform
      t.string :status, default: 'backlog', null: false
      t.string :difficulty
      t.string :route
      t.integer :progress, default: 0, null: false
      t.date :started_on
      t.date :completed_on
      t.text :notes
      t.timestamps
    end
  end

  def create_sessions
    create_table :game_sessions do |t|
      t.references :game_playthrough, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :ended_at, null: false
      t.text :notes
      t.text :milestones
      t.timestamps
    end
  end

  def create_journals
    create_table :game_journal_entries do |t|
      t.references :library_item, null: false, foreign_key: true
      t.text :body, null: false
      t.boolean :spoiler, default: false, null: false
      t.timestamps
    end
  end
end
