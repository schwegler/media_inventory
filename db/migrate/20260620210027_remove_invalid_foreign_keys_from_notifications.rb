class RemoveInvalidForeignKeysFromNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :actors unless table_exists?(:actors)
    create_table :recipients unless table_exists?(:recipients)
    
    remove_foreign_key :notifications, :actors if foreign_key_exists?(:notifications, :actors)
    remove_foreign_key :notifications, :recipients if foreign_key_exists?(:notifications, :recipients)

    drop_table :actors
    drop_table :recipients
  end
end
