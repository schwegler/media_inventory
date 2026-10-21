# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Compact profile and progress dashboard', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { User.create!(name: 'Tracker', username: 'tracker', email: 'progress@example.com', password: 'password123') }

  def track(title, type: 'TvShow', public_item: true, time: Time.current)
    series = type.constantize.create!(title: title)
    library = LibraryItem.create!(user: user, item: series, is_public: public_item)
    children = 3.times.map do |index|
      if type == 'TvShow'
        series.tv_episodes.create!(name: "Episode #{index}", season: 1, episode: index + 1)
      else
        series.comic_issues.create!(title: "Issue #{index}", issue_number: index + 1)
      end
    end
    travel_to(time) { LibraryItem.create!(user: user, item: children.first, consumed: true) }
    [series, library]
  end

  def sign_in
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  def document = Nokogiri::HTML(response.body)

  it 'previews exactly two actual recent activities and keeps the full dashboard discoverable' do
    old, library = track('Old watch', time: 3.days.ago)
    newest, = track('New comic', type: 'Comic', time: 1.hour.ago)
    middle, = track('Middle watch', time: 1.day.ago)
    library.consumption_passes.first.touch(time: 1.year.from_now)
    library.update!(rating: '5')
    old.touch(time: 2.years.from_now)
    get handle_profile_path(user.username)
    expect(document.css('.profile-progress-preview .in-progress-series-title').map(&:text).map(&:strip))
      .to eq([newest.title, middle.title])
    expect(document.at_css('a[aria-label="Open In progress dashboard"]')['href']).to include('tab=progress')
    expect(document.css('.profile-progress-preview .in-progress-log-btn')).to be_empty
    sign_in
    get handle_profile_path(user.username), params: { tab: 'progress' }
    expect(document.css('.in-progress-card').size).to eq(3)
    expect(document.css('.in-progress-log-btn').size).to eq(3)
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
    expect(document.at_css('meta[name=turbo-cache-control]')['content']).to eq('no-cache')
  end

  it 'filters, sorts and resets with a meaningful empty state and stable canonical metadata' do
    track('Zebra show')
    track('Alpha comic', type: 'Comic')
    get handle_profile_path(user.username), params: { tab: 'progress', sort: 'title' }
    expect(document.css('.in-progress-series-title').map(&:text).map(&:strip)).to eq(['Alpha comic', 'Zebra show'])
    get handle_profile_path(user.username), params: { tab: 'progress', type: 'Comic' }
    expect(document.css('.in-progress-card').size).to eq(1)
    expect(response.body).to include('Reset filters')
    expected = 'https://trove.schweg.xyz/@tracker'
    expect(document.at_css('link[rel=canonical]')['href']).to eq(expected)
    expect(document.at_css('meta[property="og:url"]')['content']).to eq(expected)
    get handle_profile_path(user.username), params: { tab: 'progress', type: 'VideoGame' }
    expect(response.body).to include('No matching titles.')
  end

  it 'keeps private series progress and all game histories out of public preview and guests' do
    track('Private series', public_item: false)
    track('Public series')
    game = VideoGame.create!(title: 'Private run game')
    library = LibraryItem.create!(user: user, item: game, is_public: true, game_activity_public: true)
    run = library.game_playthroughs.create!(status: 'currently_playing', progress: 42, notes: 'Private run notes')
    run.game_sessions.create!(started_at: 1.hour.ago, ended_at: Time.current, notes: 'Private session notes')
    sign_in
    get handle_profile_path(user.username), params: { tab: 'progress' }
    expect(response.body).to include('Private run game', '42%', 'Log session', 'Update progress', 'Private series')
    expect(response.body).not_to include('Private run notes', 'Private session notes')
    get handle_profile_path(user.username), params: { tab: 'progress', preview: 'public' }
    expect(response.body).to include('1 active title', 'Public series')
    expect(response.body).not_to include('Private series', 'Private run game', '42%', 'Log session')
    expect(document.at_css('meta[name=robots]')['content']).to eq('noindex, follow')
    delete logout_path
    get handle_profile_path(user.username), params: { tab: 'progress' }
    expect(response.body).not_to include('Private series', 'Private run game', 'Private run notes')
  end

  it 'paginates the full dashboard and keeps the single-row class scoped to the overview' do
    13.times { |index| track("Series #{index}") }
    7.times { |index| LibraryItem.create!(user: user, item: Book.create!(title: "Book #{index}"), is_collected: true) }
    get handle_profile_path(user.username)
    expect(document.css('.profile-media-row .profile-media-entry').size).to eq(6)
    expect(document.at_css('.profile-media-row')['tabindex']).to eq('0')
    get handle_profile_path(user.username), params: { tab: 'collection' }
    expect(document.css('.profile-media-row')).to be_empty
    expect(document.css('.profile-media-grid .profile-media-entry').size).to eq(7)
    get handle_profile_path(user.username), params: { tab: 'progress' }
    expect(document.css('.in-progress-card').size).to eq(12)
    expect(response.body).to include('13 active titles')
    expect(document.at_css('.pagination-wrapper nav.pagination')).to be_present
    get handle_profile_path(user.username), params: { tab: 'progress', page: 2 }
    expect(document.css('.in-progress-card').size).to eq(1)
  end
  it 'refreshes counts, preserves filters and shows a retryable validation failure for quick tracking' do
    series, library = track('Tracking actions')
    sign_in
    episode = series.tv_episodes.order(:episode).second
    headers = { 'ACCEPT' => 'text/vnd.turbo-stream.html' }
    params = { tv_episode: { consumed: true }, profile_tracking: '1', profile_tab: 'progress',
               type: 'TvShow', sort: 'title', in_progress: true }
    patch toggle_watched_tv_episode_path(episode), params: params, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('target="in_progress_section"', '1 active title', 'Episode 2')
    expect(document.at_css('#sort option[selected]')['value']).to eq('title')
    allow(ConsumptionPasses).to receive(:apply).and_return(false)
    patch toggle_watched_tv_episode_path(episode), params: params, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('role="alert"', 'Could not log this episode. Please try again.')
    patch dismiss_consumption_pass_path(library.consumption_passes.first),
          params: { profile_tracking: '1', profile_tab: 'progress' }, headers: headers
    expect(response.body).to include('0 active titles', 'Nothing in progress yet.')
  end
end
