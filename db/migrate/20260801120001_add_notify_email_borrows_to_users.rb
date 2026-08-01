# frozen_string_literal: true

class AddNotifyEmailBorrowsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notify_email_borrows, :boolean, default: true, null: false
  end
end
