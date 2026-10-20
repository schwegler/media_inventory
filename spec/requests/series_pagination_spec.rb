# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bounded series collections', type: :request do
  let(:user) { User.create!(name: 'Series reader', email: 'series@example.test', password: 'password123') }
  let(:show) { TvShow.create!(title: 'A thousand episodes') }

  def login
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  it 'renders an empty series without season-navigation errors' do
    get tv_show_path(show)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('No matching episodes')
  end

  it 'loads one bounded season page without instantiating the rest of the series' do
    TvEpisode.insert_all!(1000.times.map do |i|
      { tv_show_id: show.id, season: (i / 100) + 1, episode: (i % 100) + 1, name: "Chapter #{i}" }
    end)
    instantiated = 0
    callback = lambda do |*args|
      payload = args.last
      instantiated += payload[:record_count] if payload[:class_name] == 'TvEpisode'
    end
    ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') { get tv_show_path(show) }
    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('#series-entries .series-entry').size).to eq(30)
    expect(doc.css('*').size).to be < 3000
    expect(instantiated).to be <= 30
    expect(doc.css('#series-entries').text).to include('100 matching episodes')
    expect(doc.css('a').any? { |a| a['href'].to_s.include?('entries_page=2') }).to be true
  end

  it 'preserves deep-link season, status and query and serves a frame without the full page' do
    library = LibraryItem.create!(user: user, item: show)
    first = show.tv_episodes.create!(season: 1, episode: 1, name: 'Opening')
    last = show.tv_episodes.create!(season: 9, episode: 1, name: 'Finale')
    LibraryItem.create!(user: user, item: first, consumed: true)
    login
    get tv_show_path(show), params: { season: 9, child_q: 'Finale', child_status: 'false' },
                            headers: { 'Turbo-Frame' => 'series-entries' }
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('h1')).to be_empty
    expect(doc.css('.series-entry').size).to eq(1)
    expect(doc.at_css('.series-entry-title').text).to include(last.name)
    expect(doc.at_css('[data-child-collection-target="completed"]').text).to eq('1 of 2')
    expect(doc.at_css('select[name="season"] option[selected]')['value']).to eq('9')
    expect(library.reload.consumed?).to be false
  end

  it 'filters numbered issues and pages without loading every issue review' do
    comic = Comic.create!(title: 'Many issues')
    ComicIssue.insert_all!(65.times.map { |i| { comic_id: comic.id, issue_number: i + 1, title: "Issue #{i + 1}" } })
    get comic_path(comic), params: { entries_page: 3 }
    expect(Nokogiri::HTML(response.body).css('#series-entries .series-entry').size).to eq(5)
    get comic_path(comic), params: { child_q: '65' }
    expect(Nokogiri::HTML(response.body).css('#series-entries .series-entry').size).to eq(1)
  end

  it 'renders accessible issue navigation and clamps stale pages' do
    comic = Comic.create!(title: 'Paged issues')
    ComicIssue.insert_all!(46.times.map { |i| { comic_id: comic.id, issue_number: i + 1, title: "Chapter #{i + 1}" } })
    get comic_path(comic), params: { entries_page: 2, page: 3, child_status: 'all', child_q: 'Chapter' }
    pager = Nokogiri::HTML(response.body).at_css('nav.series-pagination')
    expect(pager).to be_present
    expect(pager.text).to include('31–46 of 46 issues', 'Page 2 of 2')
    expect(pager.at_css('[aria-disabled="true"]').text).to include('Next')
    previous = pager.at_css('a[rel="prev"]')
    query = Rack::Utils.parse_query(URI.parse(previous['href']).query)
    expect(query).to include('entries_page' => '1', 'page' => '3', 'child_q' => 'Chapter', 'child_status' => 'all')
    expect(previous['data-turbo']).to eq('false')
    expect(URI.parse(previous['href']).fragment).to eq('media-entries')
    get previous['href']
    first_page = Nokogiri::HTML(response.body)
    expect(first_page.css('#series-entries .series-entry').size).to eq(30)
    expect(first_page.at_css('.series-pagination [aria-disabled=true]').text).to include('Previous')
    expect(first_page.at_css('input[name=page]')['value']).to eq('3')
    get comic_path(comic), params: { entries_page: 999 }
    expect(Nokogiri::HTML(response.body).css('#series-entries .series-entry').size).to eq(16)
  end

  it 'uses pass-scoped progress while keeping lifetime history and other viewers private' do
    library = LibraryItem.create!(user: user, item: show)
    episode = show.tv_episodes.create!(season: 1, episode: 1, name: 'Pilot')
    child = LibraryItem.create!(user: user, item: episode, consumed: true, review: 'Private history')
    library.consumption_passes.update_all(status: 'completed')
    library.consumption_passes.create!(number: 2, status: 'active')
    login
    get tv_show_path(show), params: { child_status: 'false' }
    expect(response.body).to include('0 of 1', 'Private history')
    patch toggle_watched_tv_episode_path(episode),
          params: { series_page: '1', season: '1', tv_episode: { consumed: true } },
          headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    expect(response.body).to include('target="series-entries"', '1 of 1')
    expect(child.reload.consumed?).to be true
    delete logout_path
    get tv_show_path(show)
    expect(response.body).not_to include('Private history')
  end

  it 'retains a later page after an independent review save and subsequent tracking update' do
    LibraryItem.create!(user: user, item: show)
    TvEpisode.insert_all!(35.times.map do |i|
      { tv_show_id: show.id, season: 1, episode: i + 1, name: "Entry #{i + 1}" }
    end)
    child = show.tv_episodes.find_by!(episode: 35)
    login
    context = { item_type: 'TvEpisode', item_id: child.id, series_page: '1', season: '1', entries_page: '2' }
    get edit_review_path, params: context
    expect(Nokogiri::HTML(response.body).at_css('input[name="entries_page"]')['value']).to eq('2')
    patch review_path, params: context.merge(review: 'A later-page review'),
                       headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('input[name="series_page"]')['value']).to eq('1')
    expect(doc.at_css('input[name="entries_page"]')['value']).to eq('2')
    patch toggle_watched_tv_episode_path(child),
          params: context.merge(tv_episode: { consumed: true }), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('#series-entries .series-entry').size).to eq(5)
    expect(doc.css('#series-entries').text).to include('1 of 35', 'Entry 35')
  end
end
