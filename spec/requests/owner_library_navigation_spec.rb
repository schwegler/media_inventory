# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Owner library navigation', type: :request do
  let!(:owner) do
    User.create!(name: 'Library owner', username: 'library_owner', email: 'owner-nav@example.com',
                 password: 'password123', confirmed_at: Time.current)
  end
  let!(:other) do
    User.create!(name: 'Other reader', email: 'other-nav@example.com', password: 'password123', confirmed_at: Time.current)
  end

  def sign_in(user)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  def document = Nokogiri::HTML(response.body)

  def query(link) = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)

  it 'connects owner profile shelves to all six existing workspaces without changing public profiles' do
    movie = Movie.create!(title: 'Owner film')
    owner.library_items.create!(item: movie, is_collected: true, is_public: false, review: 'Private review sentinel')
    sign_in(owner)
    %w[collection backlog].each do |tab|
      get handle_profile_path(owner.username), params: { tab: tab }
      expect(document.css('.owner-library-tools .library-format-navigation a').size).to eq(7)
      expect(document.css('.profile-filter select#type')).not_to be_empty
      ProfilesHelper::PROFILE_MEDIA_TYPES.each_key do |type|
        get polymorphic_path(type.constantize), params: { library: 'mine' }
        active = document.at_css('.library-format-navigation a[aria-current="page"]')
        expect(URI.parse(active['href']).path).to eq(polymorphic_path(type.constantize))
        expect(query(active)).to include('library' => 'mine')
        expect(response.headers['Cache-Control']).to include('private', 'no-store')
        expect(document.at_css('.workspace-primary-nav > a[aria-current="page"]').text).to eq('My library')
      end
    end
    get movies_path, params: { library: 'mine' }
    expect(document.css('.mobile-nav-links a[aria-current="page"]').map(&:text)).to eq(['My library'])
    get movies_path, params: { library: 'mine' }, headers: { 'User-Agent' => 'Hotwire Native iOS' }
    native = document.at_css('.native-tools a[aria-current="page"]')
    expect(native.text).to eq('My library')
    expect(native['href']).to eq(user_path(owner, tab: 'collection'))
    get handle_profile_path(owner.username), params: { tab: 'collection', preview: 'public' }
    expect(document.css('.owner-library-tools')).to be_empty
    expect(response.body).not_to include('Private review sentinel')
    delete logout_path
    [nil, other].each do |viewer|
      sign_in(viewer) if viewer
      get handle_profile_path(owner.username), params: { tab: 'collection' }
      expect(document.css('.owner-library-tools')).to be_empty
      expect(response.body).not_to include('Private review sentinel')
    end
  end

  it 'keeps personal data scoped to the viewer and requires login for every format' do
    mine = Movie.create!(title: 'Only owner movie')
    theirs = Movie.create!(title: 'Only visitor movie')
    owner.library_items.create!(item: mine, is_collected: true, rating: 5, review: 'Owner private review', is_public: false)
    other.library_items.create!(item: theirs, is_collected: true)
    ProfilesHelper::PROFILE_MEDIA_TYPES.each_key do |type|
      get polymorphic_path(type.constantize), params: { library: 'mine' }
      expect(response).to redirect_to(login_path)
    end
    sign_in(other)
    get movies_path, params: { library: 'mine', user_id: owner.id }
    expect(response.body).to include(theirs.title)
    expect(response.body).not_to include(mine.title, 'Owner private review')
    get movies_path
    expect(document.css('.library-format-navigation')).to be_empty
  end

  it 'preserves compatible mode and format state without carrying stale metadata or page numbers' do
    sign_in(owner)
    filters = { library: 'mine', q: 'Story', sort: 'title', layout: 'list', status: 'physical', director: 'Director',
                page: 2 }
    get movies_path, params: filters
    current = document.at_css('.library-format-navigation a[aria-current="page"]')
    expect(query(current)).to include(filters.stringify_keys.transform_values(&:to_s))
    books = document.css('.library-format-navigation a').find { |a| a.text == 'Books' }
    expect(query(books)).to eq('library' => 'mine', 'q' => 'Story', 'sort' => 'title', 'layout' => 'list')
    browse = document.css('.library-switch a').find { |a| a.text == 'Browse catalog' }
    expect(query(browse)).to eq('q' => 'Story', 'sort' => 'title')
    get movies_path, params: { q: 'Story', sort: 'title', status: 'backlog' }
    mine = document.css('.library-switch a').find { |a| a.text == 'My library' }
    expect(query(mine)).to include('library' => 'mine', 'q' => 'Story', 'sort' => 'title', 'status' => 'backlog')
    get video_games_path, params: { library: 'mine', q: 'Story', sort: 'added', layout: 'table', play_status: 'playing' }
    books = document.css('.library-format-navigation a').find { |a| a.text == 'Books' }
    expect(query(books)).to eq('library' => 'mine', 'q' => 'Story', 'sort' => 'newest')
    saved = owner.game_library_views.create!(name: 'Saved stories',
                                             filters: { q: 'Story', sort: 'title', layout: 'list', platform: 'PC' })
    get video_games_path, params: { view: saved.id }
    books = document.css('.library-format-navigation a').find { |a| a.text == 'Books' }
    expect(query(books)).to eq('library' => 'mine', 'q' => 'Story', 'sort' => 'title', 'layout' => 'list')
    browse = document.css('.library-switch a').find { |a| a.text == 'Browse catalog' }
    expect(query(browse)).to eq('q' => 'Story', 'sort' => 'title')
  end
end
