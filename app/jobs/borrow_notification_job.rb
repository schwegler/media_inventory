# frozen_string_literal: true

class BorrowNotificationJob < ApplicationJob
  queue_as :default

  def perform(borrow_request_id, email_method)
    borrow_request = BorrowRequest.find_by(id: borrow_request_id)
    return unless borrow_request

    email_method = email_method.to_sym

    case email_method
    when :request_received
      return unless borrow_request.lender.notify_email_borrows?

      BorrowMailer.request_received(borrow_request).deliver_now
    when :request_approved
      return unless borrow_request.borrower.notify_email_borrows?

      BorrowMailer.request_approved(borrow_request).deliver_now
    when :request_declined
      return unless borrow_request.borrower.notify_email_borrows?

      BorrowMailer.request_declined(borrow_request).deliver_now
    when :item_picked_up
      return unless borrow_request.lender.notify_email_borrows?

      BorrowMailer.item_picked_up(borrow_request).deliver_now
    when :item_returned
      return unless borrow_request.borrower.notify_email_borrows?

      BorrowMailer.item_returned(borrow_request).deliver_now
    when :return_reminder
      BorrowMailer.return_reminder(borrow_request).deliver_now if borrow_request.borrower.notify_email_borrows?
      BorrowMailer.return_reminder_lender(borrow_request).deliver_now if borrow_request.lender.notify_email_borrows?
    end
  end
end
