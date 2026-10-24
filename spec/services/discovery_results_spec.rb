# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscoveryResults do
  it 'recognizes an existing provider identity even when its displayed title or year differs' do
    album = Album.create!(title: 'A corrected title', artist: 'Artist', api_id: 'itunes_7')
    user = User.create!(name: 'Synthetic Listener', password: 'password')
    user.library_items.create!(item: album, is_collected: true, is_public: false, review: 'Private opinion')
    result = { title: 'Provider title', api_id: 'itunes_7', is_local: false }
    expect(described_class.call([result], 'album', user: user).first).to include(
      is_local: true, catalog_id: album.id, in_library: true
    )
    expect(described_class.call([result], 'album').first).to include(is_local: true, in_library: false)
    expect(described_class.call([result], 'album').first).not_to have_key(:review)
  end

  it 'keeps an unimported result external without creating anything' do
    result = { title: 'Synthetic unimported album', api_id: 'itunes_77', is_local: false }
    expect(described_class.call([result], 'album')).to eq([result])
    expect(Album.count).to eq(0)
  end
end
