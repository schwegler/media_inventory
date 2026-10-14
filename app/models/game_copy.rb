# frozen_string_literal: true

# rubocop:disable-next Metrics/ClassLength
class GameCopy < ApplicationRecord
  PLATFORMS = [
    'Windows PC',
    'Nintendo Switch',
    'Nintendo Switch 2',
    'PlayStation 5',
    'PlayStation 4',
    'Xbox Series X|S',
    'Xbox One',
    'macOS',
    'Linux PC',
    'PlayStation 3',
    'PlayStation 2',
    'PlayStation',
    'Xbox 360',
    'Xbox',
    'Nintendo 3DS / DS',
    'Nintendo GameCube / Wii / Wii U',
    'Game Boy / GBA',
    'NES / SNES / N64',
    'Sega Genesis / Dreamcast',
    'iOS',
    'Android',
    'Retro console',
    'Other'
  ].freeze

  STOREFRONTS = [
    'Steam',
    'Nintendo eShop',
    'PlayStation Store',
    'Xbox Store',
    'Epic Games Store',
    'GOG',
    'Retail / Physical',
    'itch.io',
    'Battle.net',
    'EA App',
    'Ubisoft Connect',
    'App Store',
    'Google Play',
    'Amazon Games',
    'Direct / DRM-Free',
    'Other'
  ].freeze

  EDITIONS = [
    'Standard',
    'Deluxe Edition',
    "Collector's Edition",
    'Game of the Year Edition',
    'Definitive Edition',
    'Gold Edition',
    'Digital Deluxe',
    'Limited Edition',
    'Early Access',
    'Other'
  ].freeze

  CONDITIONS = [
    'Brand New / Sealed',
    'Complete in Box (CIB)',
    'Boxed without manual',
    'Cartridge / Disc only',
    'Digital code',
    'Other'
  ].freeze

  REGIONS = [
    'Region Free',
    'NTSC-U (North America)',
    'PAL (Europe)',
    'NTSC-J (Japan)',
    'Other'
  ].freeze

  CURRENCIES = %w[USD EUR GBP CAD AUD JPY].freeze

  PLATFORM_MATCHERS = {
    /Windows|PC/i => 'Windows PC',
    /Switch 2/i => 'Nintendo Switch 2',
    /Switch/i => 'Nintendo Switch',
    /PlayStation 5|PS5/i => 'PlayStation 5',
    /PlayStation 4|PS4/i => 'PlayStation 4',
    /Xbox Series/i => 'Xbox Series X|S',
    /Xbox One/i => 'Xbox One',
    /iOS|iPad/i => 'iOS',
    /Android/i => 'Android',
    /Mac/i => 'macOS',
    /Linux/i => 'Linux PC'
  }.freeze

  belongs_to :library_item
  validates :platform, presence: true
  validates :ownership_status, inclusion: { in: %w[owned wishlist previously_owned] }
  validates :access_method, inclusion: { in: %w[physical digital subscription cloud] }
  validates :purchase_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }, allow_blank: true
  validates :acquisition_source, :condition, :region, length: { maximum: 200 }
  validates :imported_playtime_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :game_library

  def self.default_platform_for(game)
    platform_str = game&.platform.to_s
    return 'Windows PC' if platform_str.blank?

    match = PLATFORM_MATCHERS.find { |pattern, _| platform_str.match?(pattern) }
    return match.last if match

    PLATFORMS.find { |p| platform_str.downcase.include?(p.downcase) } || 'Windows PC'
  end

  def self.default_storefront_for(platform)
    case platform
    when 'Windows PC', 'macOS', 'Linux PC'
      'Steam'
    when 'PlayStation 5', 'PlayStation 4', 'PlayStation 3', 'PlayStation 2', 'PlayStation'
      'PlayStation Store'
    when 'Nintendo Switch', 'Nintendo Switch 2', 'Nintendo 3DS / DS'
      'Nintendo eShop'
    when 'Xbox Series X|S', 'Xbox One', 'Xbox 360', 'Xbox'
      'Xbox Store'
    when 'iOS'
      'App Store'
    when 'Android'
      'Google Play'
    else
      'Retail / Physical'
    end
  end

  private

  def game_library
    errors.add(:library_item, 'must be a video game') unless library_item&.item_type == 'VideoGame'
  end
end
