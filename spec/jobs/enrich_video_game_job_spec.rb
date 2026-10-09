# frozen_string_literal: true

require 'rails_helper'
RSpec.describe EnrichVideoGameJob do
  it 'preserves a selected cross-provider cover and manual metadata while filling gaps' do
    game = VideoGame.create!(title: 'My Portal', developer: 'My developer',
                             thumbnail_url: '/rails/active_storage/blobs/proxy/selected/cover.webp')
    game.update_columns(api_id: 'steam_400')
    fields = { developer: 'Valve', publisher: 'Valve', game_type: 'game',
               thumbnail_url: 'https://shared.akamai.steamstatic.com/header.jpg' }
    allow_any_instance_of(MetadataProvider).to receive(:call).and_return([fields, []])
    described_class.perform_now(game)
    expect(game.reload).to have_attributes(title: 'My Portal', developer: 'My developer', publisher: 'Valve',
                                           thumbnail_url: '/rails/active_storage/blobs/proxy/selected/cover.webp')
  end
end
