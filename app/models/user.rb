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
  has_many :wrestling_events
  has_many :activities, dependent: :destroy
end
