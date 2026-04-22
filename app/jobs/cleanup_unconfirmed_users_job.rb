# frozen_string_literal: true

class CleanupUnconfirmedUsersJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    return unless user.confirmed_at.nil? && user.created_at <= 45.minutes.ago

    user.destroy
  end
end
