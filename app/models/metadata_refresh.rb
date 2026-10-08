# frozen_string_literal: true

class MetadataRefresh < ApplicationRecord
  belongs_to :item, polymorphic: true

  MESSAGES = {
    'success' => 'Metadata refreshed. Your library history and reviews are preserved.',
    'unchanged' => 'Metadata checked. No changes found.',
    'partial' => 'Some metadata was refreshed, but the provider could not supply everything. Try again later.',
    'unavailable' => 'The metadata provider is unavailable or not configured. Your existing metadata is safe.',
    'rate_limited' => 'The provider is busy. Please wait a few minutes before trying again.',
    'failed' => 'Metadata could not be refreshed. Your existing metadata is safe. Try again later.',
    'unsupported' => 'This item has no supported source ID. Suggest an edit to connect the correct source.',
    'refreshing' => 'Refreshing metadata…',
    'cooldown' => 'Metadata was recently requested. Please wait a few minutes before trying again.'
  }.freeze

  def message
    MESSAGES.fetch(state, 'Artwork and details can be checked against the original metadata source.')
  end
end
