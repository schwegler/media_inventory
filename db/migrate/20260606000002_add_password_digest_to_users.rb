# frozen_string_literal: true

class AddPasswordDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string
    remove_column :users, :login_token, :string
    remove_column :users, :login_token_sent_at, :datetime
  end
end
