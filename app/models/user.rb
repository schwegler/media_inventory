# frozen_string_literal: true

class User < ApplicationRecord
  before_save { self.email = email.downcase }
  validates :name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }

  has_many :albums, dependent: :destroy
  has_many :comics, dependent: :destroy
  has_many :movies, dependent: :destroy
  has_many :tv_shows, dependent: :destroy
  has_many :wrestling_events, dependent: :destroy

  after_create :schedule_cleanup_unconfirmed

  def generate_login_token
    update(
      login_token: SecureRandom.hex(10),
      login_token_sent_at: Time.current
    )
  end

  private

  def schedule_cleanup_unconfirmed
    CleanupUnconfirmedUsersJob.set(wait: 45.minutes).perform_later(id)
  end
end
