# frozen_string_literal: true

class CreateBorrowRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :borrow_requests do |t|
      t.references :borrower, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :lender, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :library_item, null: false, foreign_key: { on_delete: :cascade }
      t.integer :status, null: false, default: 0
      t.text :message
      t.text :lender_notes
      t.date :due_date
      t.datetime :approved_at
      t.datetime :picked_up_at
      t.datetime :returned_at
      t.datetime :last_reminder_sent_at

      t.timestamps
    end

    add_index :borrow_requests, %i[library_item_id status]
    add_index :borrow_requests, %i[borrower_id status]
    add_index :borrow_requests, %i[lender_id status]
  end
end
