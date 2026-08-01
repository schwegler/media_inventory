# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BorrowRequestsController, type: :controller do
  let(:lender) { User.create!(name: 'Lender', password: 'password123', email: 'lender@example.com') }
  let(:borrower) { User.create!(name: 'Borrower', password: 'password123', email: 'borrower@example.com') }
  let(:book) { Book.create!(title: '1984', author: 'George Orwell') }
  let(:library_item) do
    LibraryItem.create!(
      user: lender,
      item: book,
      owned_physically: true,
      is_public: true
    )
  end

  before do
    session[:user_id] = borrower.id
  end

  describe 'GET #index' do
    it 'renders the index template successfully' do
      get :index
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #create' do
    it 'creates a new borrow request and redirects back' do
      expect {
        post :create, params: { library_item_id: library_item.id, message: 'Can I read this?' }
      }.to change(BorrowRequest, :count).by(1)

      expect(flash[:success]).to include('Borrow request sent')
      expect(response).to redirect_to(borrow_requests_path)
    end
  end

  describe 'PATCH #approve' do
    let(:borrow_request) do
      BorrowRequest.create!(borrower: borrower, lender: lender, library_item: library_item)
    end

    it 'allows lender to approve' do
      session[:user_id] = lender.id
      patch :approve, params: { id: borrow_request.id, due_date: 14.days.from_now.to_date.to_s, lender_notes: 'Enjoy!' }

      expect(borrow_request.reload).to be_approved
      expect(flash[:success]).to include('Request approved')
    end

    it 'denies unauthorized user from approving' do
      session[:user_id] = borrower.id
      patch :approve, params: { id: borrow_request.id }

      expect(borrow_request.reload).to be_pending
      expect(flash[:alert]).to include('not authorized')
    end
  end

  describe 'PATCH #pick_up' do
    let(:borrow_request) do
      BorrowRequest.create!(borrower: borrower, lender: lender, library_item: library_item, status: :approved)
    end

    it 'allows borrower to confirm pickup' do
      session[:user_id] = borrower.id
      patch :pick_up, params: { id: borrow_request.id }

      expect(borrow_request.reload).to be_active
      expect(flash[:success]).to include('Confirmed!')
    end
  end

  describe 'PATCH #return_item' do
    let(:borrow_request) do
      BorrowRequest.create!(borrower: borrower, lender: lender, library_item: library_item, status: :active)
    end

    it 'allows lender to mark item returned' do
      session[:user_id] = lender.id
      patch :return_item, params: { id: borrow_request.id }

      expect(borrow_request.reload).to be_returned
      expect(flash[:success]).to include('returned')
    end
  end
end
