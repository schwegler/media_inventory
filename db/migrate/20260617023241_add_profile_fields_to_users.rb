class AddProfileFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string
    add_index :users, :username, unique: true
    add_column :users, :bio, :text
    add_column :users, :birthday, :date
    add_column :users, :notify_email_likes, :boolean, default: true
    add_column :users, :notify_push_likes, :boolean, default: true
    add_column :users, :notify_email_follows, :boolean, default: true
    add_column :users, :notify_push_follows, :boolean, default: true
    add_column :users, :notify_email_comments, :boolean, default: true
    add_column :users, :notify_push_comments, :boolean, default: true
    add_column :users, :notify_email_posts, :boolean, default: true
    add_column :users, :notify_push_posts, :boolean, default: true
  end
end
