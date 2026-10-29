# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Season zero browsing', type: :request do
  let(:show) { TvShow.create!(title: 'A show with extras') }
  let!(:extra) { show.tv_episodes.create!(season: 0, episode: 1, name: 'Behind the scenes') }
  let!(:pilot) { show.tv_episodes.create!(season: 1, episode: 1, name: 'Pilot') }

  it 'defaults to season one while retaining direct and selector access to extras' do
    get tv_show_path(show)
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('select[name="season"] option[selected]')['value']).to eq('1')
    expect(doc.at_css('select[name="season"] option[value="0"]')).to be_present
    expect(doc.at_css('.series-entry-title').text).to include('Pilot')
    get tv_show_path(show), params: { season: '0' }
    expect(Nokogiri::HTML(response.body).at_css('.series-entry-title').text).to include(extra.name)
    get tv_episode_path(extra)
    expect(response).to have_http_status(:ok)
  end

  it 'chooses an existing nonzero season when season one is absent and extras when those are all that exist' do
    pilot.update!(season: 2026)
    get tv_show_path(show)
    expect(Nokogiri::HTML(response.body).at_css('select[name="season"] option[selected]')['value']).to eq('2026')
    pilot.destroy!
    get tv_show_path(show)
    expect(Nokogiri::HTML(response.body).at_css('select[name="season"] option[selected]')['value']).to eq('0')
  end

  it 'completes normal season tracking without changing existing extra watch records' do
    user = User.create!(name: 'Viewer', email: 'extras@example.test', password: 'password')
    library = LibraryItem.create!(user: user, item: show)
    extra_library = LibraryItem.create!(user: user, item: extra, consumed: true, consumed_at: 1.year.ago.to_date)
    history = extra_library.attributes
    post login_path, params: { session: { email: user.email, password: 'password' } }
    patch mark_season_watched_tv_show_path(show, season: 1), params: { consumed: true }
    expect(library.reload).to be_consumed
    expect(extra_library.reload.attributes).to eq(history)
    get tv_show_path(show)
    expect(Nokogiri::HTML(response.body).at_css('[data-child-collection-target="completed"]').text).to eq('1 of 1')
    expect(response.body).to include('Season 0 extras do not count toward watch-through progress.')
  end
  it 'excludes extras and their legacy pass entries from personal library card progress' do
    finale = show.tv_episodes.create!(season: 1, episode: 2, name: 'Finale')
    user = User.create!(name: 'Viewer', email: 'card-extras@example.test', password: 'password')
    library = LibraryItem.create!(user: user, item: show)
    LibraryItem.create!(user: user, item: pilot, consumed: true)
    pass = library.consumption_passes.sole
    legacy = pass.entries.create!(item: extra, consumed_at: Time.current)
    before = legacy.attributes
    post login_path, params: { session: { email: user.email, password: 'password' } }
    get tv_shows_path, params: { library: 'mine' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('1 / 2 episodes watched')
    expect(legacy.reload.attributes).to eq(before)
    expect(LibraryItem.find_by(user: user, item: finale)).to be_nil
  end
end
