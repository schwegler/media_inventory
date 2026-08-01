# frozen_string_literal: true

class BorrowRequestsController < ApplicationController
  before_action :logged_in_user
  before_action :set_borrow_request, only: %i[approve decline cancel pick_up return_item]
  before_action :authorize_lender!, only: %i[approve decline return_item]
  before_action :authorize_borrower!, only: %i[cancel pick_up]

  def index
    @pending_incoming = current_user.borrow_requests_as_lender.pending_requests
                                    .includes(:borrower, library_item: :item)
                                    .order(created_at: :desc)

    @my_requests = current_user.borrow_requests_as_borrower
                               .where(status: %i[pending approved])
                               .includes(:lender, library_item: :item)
                               .order(created_at: :desc)

    @active_loans = current_user.borrow_requests_as_lender.active_loans
                                .includes(:borrower, library_item: :item)
                                .order(picked_up_at: :desc)

    @active_borrows = current_user.borrow_requests_as_borrower.active_loans
                                  .includes(:lender, library_item: :item)
                                  .order(picked_up_at: :desc)

    @history = current_user.borrow_requests_as_lender
                           .or(current_user.borrow_requests_as_borrower)
                           .where(status: %i[returned declined cancelled])
                           .includes(:borrower, :lender, library_item: :item)
                           .order(updated_at: :desc)
                           .limit(20)
  end

  def create
    library_item = LibraryItem.find(params[:library_item_id])

    @borrow_request = BorrowRequest.new(
      borrower: current_user,
      lender: library_item.user,
      library_item: library_item,
      message: params[:message]
    )

    if @borrow_request.save
      Notification.create!(
        recipient: library_item.user,
        actor: current_user,
        action: 'borrow_requested',
        notifiable: @borrow_request
      )
      BorrowNotificationJob.perform_later(@borrow_request.id, 'request_received')
      flash[:success] = "Borrow request sent for \"#{library_item.item.title}\"!"
    else
      flash[:alert] = @borrow_request.errors.full_messages.join(', ')
    end

    redirect_back fallback_location: borrow_requests_path
  end

  def approve
    due_date = params[:due_date].present? ? Date.parse(params[:due_date]) : nil
    @borrow_request.approve!(due_date: due_date, lender_notes: params[:lender_notes])
    flash[:success] = "Request approved! #{due_date ? "Due back by #{due_date.strftime('%B %d, %Y')}." : ''}"
    redirect_back fallback_location: borrow_requests_path
  end

  def decline
    @borrow_request.decline!
    flash[:success] = 'Request declined.'
    redirect_back fallback_location: borrow_requests_path
  end

  def cancel
    @borrow_request.cancel!
    flash[:success] = 'Request cancelled.'
    redirect_back fallback_location: borrow_requests_path
  end

  def pick_up
    @borrow_request.mark_picked_up!
    flash[:success] = "Confirmed! You've picked up \"#{@borrow_request.media_title}\"."
    redirect_back fallback_location: borrow_requests_path
  end

  def return_item
    @borrow_request.mark_returned!
    flash[:success] = "\"#{@borrow_request.media_title}\" has been marked as returned."
    redirect_back fallback_location: borrow_requests_path
  end

  private

  def set_borrow_request
    @borrow_request = BorrowRequest.find(params[:id])
  end

  def authorize_lender!
    return if @borrow_request.lender == current_user

    flash[:alert] = 'You are not authorized to perform this action.'
    redirect_to borrow_requests_path
  end

  def authorize_borrower!
    return if @borrow_request.borrower == current_user

    flash[:alert] = 'You are not authorized to perform this action.'
    redirect_to borrow_requests_path
  end
end
