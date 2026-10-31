# frozen_string_literal: true

class CreateBookEditionsAndReadingPasses < ActiveRecord::Migration[8.1]
  def change
    create_table :book_editions do |t|
      t.references :book, null: false, foreign_key: true
      t.string :identity_key, null: false
      t.string :label, null: false
      t.string :format, null: false
      t.string :structure_kind, null: false, default: 'chapters'
      t.string :source, null: false, default: 'manual'
      t.string :source_id
      t.string :source_url
      t.string :isbn
      t.date :published_on
      t.boolean :complete_chapter_list, null: false, default: false
      t.timestamps
    end
    add_index :book_editions, %i[book_id identity_key], unique: true
    create_table :book_chapters do |t|
      t.references :book_edition, null: false, foreign_key: true
      t.string :identity_key, null: false
      t.integer :position, null: false
      t.string :label
      t.string :title
      t.string :part
      t.string :provenance, null: false, default: 'manual'
      t.timestamps
    end
    add_index :book_chapters, %i[book_edition_id identity_key], unique: true
    add_index :book_chapters, %i[book_edition_id position], unique: true
    create_table :book_reading_passes do |t|
      t.references :library_item, null: false, foreign_key: true
      t.references :book_edition, null: false, foreign_key: true
      t.integer :number, null: false
      t.timestamps
    end
    add_index :book_reading_passes, %i[library_item_id book_edition_id number], unique: true, name: 'book_pass_number'
    create_table :book_chapter_completions do |t|
      t.references :book_reading_pass, null: false, foreign_key: true
      t.references :book_chapter, null: false, foreign_key: true
      t.timestamps
    end
    add_index :book_chapter_completions, %i[book_reading_pass_id book_chapter_id], unique: true, name: 'book_pass_chapter'
  end
end
