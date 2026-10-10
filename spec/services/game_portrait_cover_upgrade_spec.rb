# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GamePortraitCoverUpgrade do
  let(:game) { VideoGame.create!(title: 'Portal', api_id: 'steam_400') }

  def cover(width:, height:, remote: true)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('image'), filename: 'cover.webp',
                                           content_type: 'image/webp', identify: false,
                                           metadata: { width: width, height: height,
                                                       remote_source: remote ? 'https://example.com/cover.jpg' : nil })
  end

  it 'upgrades a landscape provider cover only after a portrait is acquired' do
    game.cover_image.attach(cover(width: 460, height: 215))
    portrait = cover(width: 600, height: 900)
    allow(GameSearchArtwork).to receive(:acquire).and_return(portrait)
    expect(described_class.call(game)).to eq(:updated)
    expect(game.reload.cover_image.blob).to eq(portrait)
  end

  it 'retains the existing cover if portrait artwork is unavailable' do
    original = cover(width: 460, height: 215)
    game.cover_image.attach(original)
    allow(GameSearchArtwork).to receive(:acquire).and_return(nil)
    expect(described_class.call(game)).to eq(:unavailable)
    expect(game.reload.cover_image.blob).to eq(original)
  end

  it 'preserves uploaded covers and existing portraits' do
    [cover(width: 460, height: 215, remote: false), cover(width: 600, height: 900)].each do |original|
      game.cover_image.attach(original)
      expect(GameSearchArtwork).not_to receive(:acquire)
      expect(described_class.call(game)).to eq(:skipped)
      expect(game.reload.cover_image.blob).to eq(original)
    end
  end
end
