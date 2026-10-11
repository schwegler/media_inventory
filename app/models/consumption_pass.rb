# frozen_string_literal: true

# One run through a series: a watch (or re-watch) of a TV show, a read (or re-read) of a comic.
class ConsumptionPass < ApplicationRecord
  STATUSES = %w[active completed dismissed].freeze
  SERIES_TYPES = %w[TvShow Comic].freeze

  belongs_to :library_item
  has_many :entries, class_name: 'ConsumptionPassEntry', dependent: :delete_all

  validates :status, inclusion: { in: STATUSES }
  validates :number, numericality: { only_integer: true, greater_than: 0 }
  validate :series_library_item

  scope :active, -> { where(status: 'active') }
  scope :recent_first, -> { order(number: :desc) }

  def active? = status == 'active'
  def completed? = status == 'completed'
  def dismissed? = status == 'dismissed'
  def rewatch? = number > 1

  private

  def series_library_item
    return if SERIES_TYPES.include?(library_item&.item_type)

    errors.add(:library_item, 'must be a TV show or comic')
  end
end
