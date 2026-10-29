# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadataChildren do
  let(:show) { TvShow.create!(title: 'Ghosts') }
  let(:special) do
    { 'id' => 3_684_533, 'name' => 'Halloween 6: The Mirror – Parts One & Two',
      'season' => 6, 'number' => nil, 'type' => 'significant_special', 'airdate' => '2026-10-29' }
  end

  it 'retains the same record and personal history when a provider later numbers a special' do
    described_class.episodes(show, [special])
    episode = show.tv_episodes.sole
    user = User.create!(name: 'Viewer', password: 'password')
    library = LibraryItem.create!(user: user, item: episode, consumed: true, review: 'Keep this')
    comment = Comment.create!(user: user, commentable: episode, content: 'A comment')
    described_class.episodes(show, [special.merge('number' => 1, 'type' => 'regular')])
    expect(show.tv_episodes.sole.id).to eq(episode.id)
    expect(episode.reload.episode).to eq(1)
    expect(episode.metadata_details['Episode type']).to eq('regular')
    expect(library.reload.consumed).to be true
    expect(library.review).to eq('Keep this')
    expect(comment.reload.commentable_id).to eq(episode.id)
    described_class.episodes(show, [special])
    expect(show.tv_episodes.sole.reload.episode).to be_nil
  end

  it 'backfills provider IDs on legacy numbered records without duplicating them' do
    episode = show.tv_episodes.create!(season: 1, episode: 1, name: 'Custom pilot')
    described_class.episodes(show, [{ 'id' => 100, 'season' => 1, 'number' => 1, 'name' => 'Pilot' }])
    expect(show.tv_episodes.sole.id).to eq(episode.id)
    expect(episode.reload.provider_id).to eq('100')
    expect(episode.name).to eq('Custom pilot')
  end

  it 'does not overwrite an identified episode when another provider ID occupies its old number' do
    first = show.tv_episodes.create!(season: 6, episode: 1, name: 'Keep this', provider_id: '100')
    described_class.episodes(show, [special.merge('number' => 1)])
    expect(first.reload.provider_id).to eq('100')
    expect(show.tv_episodes.find_by!(provider_id: '3684533').id).not_to eq(first.id)
  end

  it 'skips malformed unnumbered records rather than assigning a made-up number or identity' do
    invalid = [special.except('id'), special.merge('type' => 'regular'), special.merge('number' => '1'),
               special.merge('season' => nil)]
    expect { described_class.episodes(show, invalid) }.not_to change(TvEpisode, :count)
  end
end
