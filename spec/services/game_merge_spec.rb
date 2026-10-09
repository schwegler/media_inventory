# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Game catalog reconciliation' do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:source) { VideoGame.create!(title: 'Source game', api_id: 'steam_400') }
  let(:target) { VideoGame.create!(title: 'Retained game', api_id: 'rawg_22') }

  it 'moves strong provider mappings and keeps copy and gameplay associations intact' do
    library = LibraryItem.create!(user: user, item: source, review: 'Preserve my review')
    copy = library.game_copies.create!(platform: 'PC', notes: 'Receipt')
    run = library.game_playthroughs.create!(notes: 'Route notes')
    Admin::MergeMedia.call(source, target)
    expect(library.reload.item).to eq(target)
    expect(GameExternalId.where(video_game: target).pluck(:provider)).to contain_exactly('steam', 'rawg')
    expect(copy.reload.library_item).to eq(library)
    expect(run.reload.notes).to eq('Route notes')
    expect(library.review).to eq('Preserve my review')
  end

  it 'blocks overlapping personal records instead of hiding or discarding a members history' do
    LibraryItem.create!(user: user, item: source, review: 'First review')
    LibraryItem.create!(user: user, item: target, review: 'Second review')
    expect { Admin::MergeMedia.call(source, target) }.to raise_error(Admin::MergeMedia::Conflict, /personal history/)
    expect(VideoGame.exists?(source.id)).to be true
    expect(source.game_external_ids.count).to eq(1)
    expect(user.library_items.pluck(:review)).to contain_exactly('First review', 'Second review')
  end
end
