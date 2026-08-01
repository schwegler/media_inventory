# frozen_string_literal: true

class BorrowReminderJob < ApplicationJob
  queue_as :default

  def perform
    send_due_soon_reminders
    send_overdue_reminders
  end

  private

  # Send reminders for items due within 3 days
  def send_due_soon_reminders
    BorrowRequest.active_loans
                 .where.not(due_date: nil)
                 .where(due_date: Date.current..3.days.from_now.to_date)
                 .where('last_reminder_sent_at IS NULL OR last_reminder_sent_at < ?', 1.day.ago)
                 .find_each do |request|
      request.send_reminder!
    end
  end

  # Send weekly reminders for overdue items
  def send_overdue_reminders
    BorrowRequest.active_loans
                 .where.not(due_date: nil)
                 .where('due_date < ?', Date.current)
                 .where('last_reminder_sent_at IS NULL OR last_reminder_sent_at < ?', 7.days.ago)
                 .find_each do |request|
      request.send_reminder!
    end
  end
end
