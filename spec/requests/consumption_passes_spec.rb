# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Consumption passes' do
  let!(:user) do
    User.create!(name: 'Rewatcher', email: 'rewatch@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end
  let!(:other) do
    User.create!(name: 'Other', email: 'other-pass@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end
  let!(:show) { TvShow.create!(title: 'Stargate SG-1') }
  let!(:show_lib) { LibraryItem.create!(user: user, item: show, is_public: true) }
  let!(:ep1) { show.tv_episodes.create!(name: 'Children of the Gods', season: 1, episode: 1) }
  let!(:ep2) { show.tv_episodes.create!(name: 'The Enemy Within', season: 1, episode: 2) }
  let!(:ep3) { show.tv_episodes.create!(name: 'Emancipation', season: 1, episode: 3) }

  before do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    patch toggle_watched_tv_episode_path(ep1), params: { tv_episode: { consumed: true } }
  end

  it 'tracks the show from the first watch' do
    expect(InProgressTracker.items_for(user).map(&:series)).to eq([show])
  end

  it 'dismisses a show from In progress without losing progress' do
    pass = show_lib.consumption_passes.sole
    patch dismiss_consumption_pass_path(pass)

    expect(InProgressTracker.items_for(user)).to be_empty
    expect(pass.reload.entries.count).to eq(1)
    expect(LibraryItem.find_by(user: user, item: ep1)).to be_consumed
  end

  it 'removes the card via turbo stream on dismiss' do
    patch dismiss_consumption_pass_path(show_lib.consumption_passes.sole), as: :turbo_stream

    expect(response.body).to include("turbo-stream action=\"remove\" target=\"in_progress_tv_show_#{show.id}\"")
  end

  it 'starts a re-watch that appears at 0% with episode one up next' do
    patch dismiss_consumption_pass_path(show_lib.consumption_passes.sole)
    post consumption_passes_path(library_item_id: show_lib.id)

    item = InProgressTracker.items_for(user).sole
    expect(item.pass.number).to eq(2)
    expect(item.completed_count).to eq(0)
    expect(item.percent).to eq(0)
    expect(item.next_item).to eq(ep1)
  end

  it 'advances the re-watch from the In progress card without touching the first pass' do
    post consumption_passes_path(library_item_id: show_lib.id)
    patch toggle_watched_tv_episode_path(ep1), params: { tv_episode: { consumed: true }, in_progress: true }

    item = InProgressTracker.items_for(user).sole
    expect(item.completed_count).to eq(1)
    expect(item.next_item).to eq(ep2)
    expect(show_lib.consumption_passes.find_by(number: 1).entries.count).to eq(1)
  end

  it "does not let another user dismiss or start someone else's pass" do
    pass = show_lib.consumption_passes.sole
    delete logout_path
    post login_path, params: { session: { email: other.email, password: 'password123' } }

    patch dismiss_consumption_pass_path(pass)
    expect(response).to have_http_status(:not_found)
    post consumption_passes_path(library_item_id: show_lib.id)
    expect(response).to have_http_status(:not_found)
    expect(pass.reload).to be_active
  end

  it 'renders a dismiss button on the owner profile' do
    get user_path(user)
    expect(response.body).to include('Dismiss')
  end

  describe 're-watching from the show page' do
    before do
      # Complete the first pass
      patch toggle_watched_tv_episode_path(ep2), params: { tv_episode: { consumed: true } }
      patch toggle_watched_tv_episode_path(ep3), params: { tv_episode: { consumed: true } }
      # Start re-watch (pass 2)
      post consumption_passes_path(library_item_id: show_lib.id)
    end

    it 'renders episodes as unwatched on the show page at start of re-watch' do
      get tv_show_path(show)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('0 of 3')
      expect(response.body).to include('Rewatch #1')
      expect(response.body).to include('Mark watched')
      expect(response.body).to include('Mark watched')
    end

    it 'marks an episode watched from the show page and updates re-watch progress' do
      patch toggle_watched_tv_episode_path(ep1), params: { tv_episode: { consumed: true } }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include('✓ Watched')
      expect(response.body).to include('Undo')

      pass2 = show_lib.consumption_passes.find_by(number: 2)
      expect(pass2.entries.pluck(:item_id)).to eq([ep1.id])
      expect(show_lib.consumption_passes.find_by(number: 1).entries.count).to eq(3)

      get tv_show_path(show)
      expect(response.body).to include('1 of 3')
    end

    it 'allows marking an episode watched during re-watch even if previously reviewed' do
      ep1_lib = LibraryItem.find_by(user: user, item: ep1)
      ep1_lib.update!(rating: '4.0', review: 'Great episode')

      get tv_show_path(show)
      expect(response.body).to include('Mark watched')

      patch toggle_watched_tv_episode_path(ep1), params: { tv_episode: { consumed: true } }, as: :turbo_stream
      expect(response).to have_http_status(:success)

      pass2 = show_lib.consumption_passes.find_by(number: 2)
      expect(pass2.entries.pluck(:item_id)).to eq([ep1.id])
    end

    it 'allows undoing an episode in a re-watch from the show page while preserving lifetime history' do
      patch toggle_watched_tv_episode_path(ep1), params: { tv_episode: { consumed: true } }
      pass2 = show_lib.consumption_passes.find_by(number: 2)
      expect(pass2.entries.pluck(:item_id)).to eq([ep1.id])

      patch toggle_watched_tv_episode_path(ep1),
            params: { tv_episode: { consumed: false, consumed_at: nil } }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Mark watched')
      expect(pass2.reload.entries).to be_empty
      expect(LibraryItem.find_by(user: user, item: ep1)).to be_consumed
    end
  end
end
