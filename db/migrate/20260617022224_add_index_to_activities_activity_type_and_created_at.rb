# frozen_string_literal: true

class AddIndexToActivitiesActivityTypeAndCreatedAt < ActiveRecord::Migration[8.1]
  def change
    add_index :activities, [:activity_type, :created_at], name: 'index_activities_on_type_and_created_at'
  end
end
