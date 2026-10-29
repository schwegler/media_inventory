# frozen_string_literal: true

class EditorialArticleTitle < ApplicationRecord
  belongs_to :editorial_article
  belongs_to :item, polymorphic: true
end
