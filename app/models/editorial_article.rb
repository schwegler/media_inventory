# frozen_string_literal: true

class EditorialArticle < ApplicationRecord
  has_many :editorial_article_titles, dependent: :delete_all
  validates :wordpress_id, numericality: { only_integer: true, greater_than: 0 }, uniqueness: true
  validates :title, :canonical_url, :source_modified_at, :checked_at, presence: true

  def self.for_title(item)
    joins(:editorial_article_titles).where(published: true,
                                           editorial_article_titles: { item_type: item.class.name, item_id: item.id })
                                    .order(published_at: :desc, wordpress_id: :desc).limit(6)
  end
end
