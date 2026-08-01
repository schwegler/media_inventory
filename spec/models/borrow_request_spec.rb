# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BorrowRequest, type: :model do
  let(:lender) { User.create!(name: 'Lender', password: 'password123', email: 'lender@example.com') }
  let(:borrower) { User.create!(name: 'Borrower', password: 'password123', email: 'borrower@example.com') }
  let(:book) { Book.create!(title: 'The Great Gatsby', author: 'F. Scott Fitzgerald') }
  let(:library_item) do
    LibraryItem.create!(
      user: lender,
      item: book,
      owned_physically: true,
      is_public: true
    )
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      request = BorrowRequest.new(borrower: borrower, lender: lender, library_item: library_item)
      expect(request).to be_valid
    end

    it 'is invalid if borrower is lender' do
      request = BorrowRequest.new(borrower: lender, lender: lender, library_item: library_item)
      expect(request).not_to be_valid
      expect(request.errors[:borrower]).to include("can't borrow from yourself")
    end

    it 'is invalid if item is not owned physically' do
      digital_item = LibraryItem.create!(user: lender, item: book, owned_physically: false, is_public: true)
      request = BorrowRequest.new(borrower: borrower, lender: lender, library_item: digital_item)
      expect(request).not_to be_valid
      expect(request.errors[:library_item]).to include('must be a physically owned item')
    end

    it 'prevents duplicate pending requests' do
      BorrowRequest.create!(borrower: borrower, lender: lender, library_item: library_item, status: :pending)
      duplicate = BorrowRequest.new(borrower: borrower, lender: lender, library_item: library_item, status: :pending)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include('You already have an active or pending request for this item')
    end
  end

  describe 'state transitions' do
    let(:borrow_request) { BorrowRequest.create!(borrower: borrower, lender: lender, library_item: library_item) }

    it 'transitions to approved and creates notification' do
      expect {
        borrow_request.approve!(due_date: 7.days.from_now.to_date, lender_notes: 'Leave at front door')
      }.to change(Notification, :count).by(1)

      expect(borrow_request.reload).to be_approved
      expect(borrow_request.due_date).to eq(7.days.from_now.to_date)
      expect(borrow_request.lender_notes).to eq('Leave at front door')
    end

    it 'transitions to declined and notifies borrower' do
      expect {
        borrow_request.decline!
      }.to change(Notification, :count).by(1)

      expect(borrow_request.reload).to be_declined
    end

    it 'transitions from approved to active on pickup' do
      borrow_request.approve!(due_date: 7.days.from_now.to_date)

      expect {
        borrow_request.mark_picked_up!
      }.to change(Notification, :count).by(1)

      expect(borrow_request.reload).to be_active
      expect(library_item.reload).to be_currently_lent
    end

    it 'transitions from active to returned' do
      borrow_request.approve!(due_date: 7.days.from_now.to_date)
      borrow_request.mark_picked_up!

      expect {
        borrow_request.mark_returned!
      }.to change(Notification, :count).by(1)

      expect(borrow_request.reload).to be_returned
      expect(library_item.reload).not_to be_currently_lent
    end
  end

  describe 'overdue calculations' do
    let(:borrow_request) do
      BorrowRequest.create!(
        borrower: borrower,
        lender: lender,
        library_item: library_item,
        status: :active,
        due_date: 2.days.ago.to_date,
        picked_up_at: 5.days.ago
      )
    end

    it 'identifies overdue requests' do
      expect(borrow_request.overdue?).to be true
      expect(BorrowRequest.overdue).to include(borrow_request)
    end
  end
end
