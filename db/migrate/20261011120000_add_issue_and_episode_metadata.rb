# frozen_string_literal: true

class AddIssueAndEpisodeMetadata < ActiveRecord::Migration[8.0]
  def change
    %i[comic_issues tv_episodes].each do |table|
      add_column table, :credits, :json, default: [], null: false
      add_column table, :metadata_details, :json, default: {}, null: false
    end
    add_column :tv_episodes, :provider_id, :string
  end
end
