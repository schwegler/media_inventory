# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media catalog organization', type: :request do
  let(:user) { User.create!(name: 'Reader', email: 'catalog@example.com', password: 'password123') }

  it 'renders the shared catalog and detail sections for every supported media type' do
    [Movie, TvShow, Book, Album, Comic, VideoGame].each do |klass|
      item = klass.create!(title: "Example #{klass.name}")
      get polymorphic_path(klass)
      expect(response).to have_http_status(:ok)
      if klass == VideoGame
        expect(response.body).to include('Search collection', 'game-library-filters')
      else
        expect(response.body).to include('Search by title', 'catalog-navigation')
      end
      get polymorphic_path(item)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      expect(document.css('#my-library, #community, #comments').size).to eq(3)
      expect(document.at_css('h1').text).to eq(item.title)
    end
  end

  it 'searches the entire catalog, sorts results, and preserves filters across pagination' do
    27.times { |i| VideoGame.create!(title: "Matching Game #{i.to_s.rjust(2, '0')}") }
    VideoGame.create!(title: 'Unrelated title')
    get video_games_path(q: 'matching', sort: 'title')
    document = Nokogiri::HTML(response.body)
    titles = document.css('.card-2026-title').map(&:text)
    expect(titles.first).to eq('Matching Game 00')
    expect(titles.size).to eq(24)
    expect(titles.last).to eq('Matching Game 23')
    expect(document.css('.pagination a').map { |a| a['href'] }.join).to include('q=matching', 'sort=title')
    get video_games_path(q: 'matching', sort: 'title', page: 2)
    expect(response.body).to include('Matching Game 24', 'Matching Game 25', 'Matching Game 26')
    expect(response.body).not_to include('Unrelated title')
  end

  it 'treats SQL wildcard characters as literal search text' do
    Movie.create!(title: '100% Fun')
    Movie.create!(title: 'Another movie')
    get movies_path(q: '%')
    document = Nokogiri::HTML(response.body)
    expect(document.css('.card-2026-title').map(&:text)).to eq(['100% Fun'])
  end

  it 'filters library status using only the signed-in user entries' do
    other = User.create!(name: 'Other', email: 'other-catalog@example.com', password: 'password123')
    own = Book.create!(title: 'My collected book')
    theirs = Book.create!(title: 'Someone else book')
    LibraryItem.create!(user: user, item: own, is_collected: true)
    LibraryItem.create!(user: other, item: theirs, is_collected: true)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    get books_path(status: 'collection')
    document = Nokogiri::HTML(response.body)
    expect(document.css('.card-2026-title').map(&:text)).to eq(['My collected book'])
  end

  it 'distinguishes an empty search from an empty catalog' do
    get albums_path(q: 'no-such-album')
    expect(response.body).to include('No matching titles', 'View all titles')
    expect(response.body).not_to include('This shelf is waiting')
  end
  it 'keeps child tracking forms available on parent and child detail pages' do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    show = TvShow.create!(title: 'Series')
    episode = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
    comic = Comic.create!(title: 'Comic series')
    issue = comic.comic_issues.create!(title: 'First issue', issue_number: 1)
    [show, comic].each { |parent| LibraryItem.create!(user: user, item: parent, is_collected: true) }
    [[show, episode, 'Watch, rate, or review'], [comic, issue, 'Read, rate, or review']].each do |parent, child, label|
      get polymorphic_path(parent)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(label, 'child-collection', 'child-status')
      get polymorphic_path(child)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('My Progress', 'Review &amp; rating')
    end
  end

  it 'keeps signed-in child pages distinct from missing parent-library membership' do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    show = TvShow.create!(title: 'Untracked series')
    episode = show.tv_episodes.create!(name: 'First episode', season: 1, episode: 1)
    comic = Comic.create!(title: 'Untracked comic')
    issue = comic.comic_issues.create!(title: 'First issue', issue_number: 1)

    [episode, issue].each do |child|
      get "/#{child.class.model_name.route_key}/#{child.id}"
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Add series to my library', 'Account menu')
      expect(response.body).not_to include('to log your progress for this')
      get root_path
      expect(response.body).to include('Welcome back', user.name)
    end
  end
end
