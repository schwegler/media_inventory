# frozen_string_literal: true

class AddPasswordlessAuthToUsers < ActiveRecord::Migration[7.1]
  def change
    remove_column :users, :password_digest, :string
    add_column :users, :login_token, :string
    add_column :users, :login_token_sent_at, :datetime
    add_column :users, :confirmed_at, :datetime
  end
end
