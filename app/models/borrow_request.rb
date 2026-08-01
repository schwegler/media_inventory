# frozen_string_literal: true

class BorrowRequest < ApplicationRecord
  belongs_to :borrower, class_name: 'User'
  belongs_to :lender, class_name: 'User'
  belongs_to :library_item

  enum :status, {
    pending: 0,
    approved: 1,
    active: 2,
    returned: 3,
    declined: 4,
    cancelled: 5
  }

  # --- Validations ---
  validate :borrower_is_not_lender
  validate :item_is_physically_owned
  validate :no_duplicate_pending_request, on: :create

  # --- Scopes ---
  scope :active_loans, -> { where(status: :active) }
  scope :pending_requests, -> { where(status: :pending) }
  scope :in_progress, -> { where(status: %i[pending approved active]) }
  scope :completed, -> { where(status: %i[returned declined cancelled]) }
  scope :overdue, -> { active_loans.where('due_date < ?', Date.current) }
  scope :due_soon, ->(days = 3) { active_loans.where(due_date: Date.current..days.days.from_now.to_date) }
  scope :needs_reminder, lambda {
    active_loans
      .where.not(due_date: nil)
      .where('last_reminder_sent_at IS NULL OR last_reminder_sent_at < ?', 1.day.ago)
  }

  # --- State Transitions ---

  def approve!(due_date: nil, lender_notes: nil)
    return false unless pending?

    update!(
      status: :approved,
      due_date: due_date,
      lender_notes: lender_notes,
      approved_at: Time.current
    )
    create_notification!(:borrow_approved, recipient: borrower, actor: lender)
    enqueue_email_notification(:request_approved)
  end

  def decline!
    return false unless pending?

    update!(status: :declined)
    create_notification!(:borrow_declined, recipient: borrower, actor: lender)
    enqueue_email_notification(:request_declined)
  end

  def cancel!
    return false unless pending?

    update!(status: :cancelled)
    create_notification!(:borrow_cancelled, recipient: lender, actor: borrower)
  end

  def mark_picked_up!
    return false unless approved?

    update!(status: :active, picked_up_at: Time.current)
    create_notification!(:borrow_picked_up, recipient: lender, actor: borrower)
    enqueue_email_notification(:item_picked_up)
  end

  def mark_returned!
    return false unless active?

    update!(status: :returned, returned_at: Time.current)
    create_notification!(:borrow_returned, recipient: borrower, actor: lender)
    enqueue_email_notification(:item_returned)
  end

  # Called by the reminder job
  def send_reminder!
    return unless active? && due_date.present?

    update!(last_reminder_sent_at: Time.current)
    create_notification!(:borrow_reminder, recipient: borrower, actor: lender)
    BorrowNotificationJob.perform_later(id, :return_reminder)
  end

  def overdue?
    active? && due_date.present? && due_date < Date.current
  end

  def due_soon?(days = 3)
    active? && due_date.present? && due_date <= days.days.from_now.to_date && due_date >= Date.current
  end

  def days_until_due
    return nil unless due_date.present?

    (due_date - Date.current).to_i
  end

  def media_title
    library_item&.item&.title || 'Unknown Item'
  end

  private

  def borrower_is_not_lender
    errors.add(:borrower, "can't borrow from yourself") if borrower_id == lender_id
  end

  def item_is_physically_owned
    return if library_item&.owned_physically?

    errors.add(:library_item, 'must be a physically owned item')
  end

  def no_duplicate_pending_request
    return unless BorrowRequest.where(
      borrower: borrower,
      library_item: library_item,
      status: %i[pending approved active]
    ).exists?

    errors.add(:base, 'You already have an active or pending request for this item')
  end

  def create_notification!(action, recipient:, actor:)
    Notification.create!(
      recipient: recipient,
      actor: actor,
      action: action.to_s,
      notifiable: self
    )
  end

  def enqueue_email_notification(email_method)
    BorrowNotificationJob.perform_later(id, email_method.to_s)
  end
end
