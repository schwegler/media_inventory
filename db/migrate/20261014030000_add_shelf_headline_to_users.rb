# frozen_string_literal: true

class AddShelfHeadlineToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :shelf_headline, :string
  end
end
