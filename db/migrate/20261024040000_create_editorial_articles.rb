# frozen_string_literal: true

class CreateEditorialArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :editorial_articles do |t|
      t.bigint :wordpress_id, null: false
      t.string :title, null: false
      t.text :excerpt
      t.string :canonical_url, null: false
      t.string :image_url
      t.datetime :published_at
      t.datetime :source_modified_at, null: false
      t.datetime :checked_at, null: false
      t.boolean :published, null: false, default: true
      t.timestamps
    end
    add_index :editorial_articles, :wordpress_id, unique: true
    add_index :editorial_articles, :checked_at

    create_table :editorial_article_titles do |t|
      t.references :editorial_article, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
    end
    add_index :editorial_article_titles, %i[editorial_article_id item_type item_id],
              unique: true, name: 'index_editorial_article_titles_unique'
  end
end
