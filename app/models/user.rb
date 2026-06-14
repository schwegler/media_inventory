# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  before_validation { self.email = nil if email.blank? }
  before_save { self.email = email.downcase if email.present? }

  validates :name, presence: true, length: { maximum: 50 }
  validates :email, length: { maximum: 255 },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false },
                    allow_nil: true

  has_many :albums
  has_many :comics
  has_many :movies
  has_many :tv_shows
  has_many :video_games
  has_many :activities, dependent: :destroy
  has_many :comments, dependent: :destroy

  def display_handle
    if bsky_handle.present?
      "@#{bsky_handle.sub(/^@/, '')}"
    else
      email
    end
  end

  before_create :generate_activitypub_keys

  private

  def generate_activitypub_keys
    require 'openssl'
    key = OpenSSL::PKey::RSA.new(2048)
    self.private_key = key.to_pem
    self.public_key = key.public_key.to_pem
  end
end
