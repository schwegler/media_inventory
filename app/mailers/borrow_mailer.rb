# frozen_string_literal: true

class BorrowMailer < ApplicationMailer
  default from: 'notifications@trove.app'

  def request_received(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title

    mail(
      to: @lender.email,
      subject: "#{@borrower.name} wants to borrow \"#{@item_title}\""
    ) if @lender.email.present?
  end

  def request_approved(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title

    mail(
      to: @borrower.email,
      subject: "Your borrow request for \"#{@item_title}\" was approved!"
    ) if @borrower.email.present?
  end

  def request_declined(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title

    mail(
      to: @borrower.email,
      subject: "Your borrow request for \"#{@item_title}\" was declined"
    ) if @borrower.email.present?
  end

  def item_picked_up(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title

    mail(
      to: @lender.email,
      subject: "#{@borrower.name} has picked up \"#{@item_title}\""
    ) if @lender.email.present?
  end

  def item_returned(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title

    mail(
      to: @borrower.email,
      subject: "\"#{@item_title}\" has been marked as returned"
    ) if @borrower.email.present?
  end

  def return_reminder(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title
    @overdue = borrow_request.overdue?
    @days = borrow_request.days_until_due

    subject = if @overdue
                "Reminder: \"#{@item_title}\" is overdue"
              else
                "Reminder: \"#{@item_title}\" is due #{@days.zero? ? 'today' : "in #{@days} #{'day'.pluralize(@days)}"}"
              end

    mail(
      to: @borrower.email,
      subject: subject
    ) if @borrower.email.present?
  end

  def return_reminder_lender(borrow_request)
    @borrow_request = borrow_request
    @borrower = borrow_request.borrower
    @lender = borrow_request.lender
    @item_title = borrow_request.media_title
    @overdue = borrow_request.overdue?
    @days = borrow_request.days_until_due

    subject = if @overdue
                "\"#{@item_title}\" lent to #{@borrower.name} is overdue"
              else
                "\"#{@item_title}\" lent to #{@borrower.name} is due #{@days.zero? ? 'today' : "in #{@days} #{'day'.pluralize(@days)}"}"
              end

    mail(
      to: @lender.email,
      subject: subject
    ) if @lender.email.present?
  end
end
