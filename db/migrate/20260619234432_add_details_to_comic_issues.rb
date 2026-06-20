# frozen_string_literal: true

class AddDetailsToComicIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :comic_issues, :issue_number, :integer
    add_column :comic_issues, :summary, :text
    add_column :comic_issues, :read, :boolean, default: false, null: false
    add_column :comic_issues, :read_at, :date
    add_column :comic_issues, :rating, :string
    add_column :comic_issues, :review, :text
  end
end
