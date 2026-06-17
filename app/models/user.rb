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
  validates :username, length: { maximum: 30 },
                       format: { with: /\A[a-zA-Z0-9_]+\z/ },
                       uniqueness: { case_sensitive: false },
                       allow_nil: true

  has_one_attached :avatar
  has_one_attached :header_banner

  has_many :albums
  has_many :comics
  has_many :movies
  has_many :tv_shows
  has_many :video_games
  has_many :activities, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy

  has_many :active_relationships, class_name: 'Relationship',
                                  foreign_key: 'follower_id',
                                  dependent: :destroy
  has_many :passive_relationships, class_name: 'Relationship',
                                   foreign_key: 'followed_id',
                                   dependent: :destroy
  has_many :following, through: :active_relationships,  source: :followed
  has_many :followers, through: :passive_relationships, source: :follower

  def liked?(likeable)
    likes.exists?(likeable_type: likeable.class.name, likeable_id: likeable.id)
  end

  def follow(other_user)
    following << other_user unless self == other_user
  end

  def unfollow(other_user)
    following.delete(other_user)
  end

  def following?(other_user)
    following.include?(other_user)
  end

  def display_handle
    if username.present?
      "@#{username}"
    elsif bsky_handle.present?
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
