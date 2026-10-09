# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile redesign', type: :request do
  it 'renders apostrophes and special characters once in browser and social titles' do
    user = User.create!(name: "O'Reilly & <script>alert(1)</script>", password: 'password123')
    get user_path(user)
    document = Nokogiri::HTML(response.body)
    expected = "#{user.name}'s library | Trove"
    expect(document.at_css('title').text).to eq(expected)
    expect(document.at_css('meta[property="og:title"]')['content']).to eq(expected)
    expect(document.at_css('meta[name="twitter:title"]')['content']).to eq(expected)
    expect(document.css('title script')).to be_empty
  end

  let!(:owner) do
    User.create!(name: 'Library Owner', username: 'library_owner', email: 'owner-profile@example.com',
                 password: 'password123', birthday: Date.new(1990, 2, 3))
  end
  let!(:public_movie) { Movie.create!(title: 'Visible movie') }
  let!(:private_movie) { Movie.create!(title: 'Secret movie') }
  let!(:public_entry) do
    LibraryItem.create!(user: owner, item: public_movie, is_collected: true, is_public: true, review: 'Visible review')
  end
  let!(:private_entry) do
    LibraryItem.create!(user: owner, item: private_movie, is_collected: true, in_backlog: true, is_public: false,
                        review: 'Secret review')
  end

  def sign_in(user)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  it 'serves readable and legacy numeric URLs, case-insensitively, with a stable canonical link' do
    [user_path(owner), "/users/#{owner.id}", '/users/LIBRARY_OWNER'].each do |url|
      get url
      unless url == user_path(owner)
        expect(response).to have_http_status(:moved_permanently)
        expect(response).to redirect_to(user_path(owner))
        follow_redirect!
      end
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('https://trove.schweg.xyz/users/library_owner')
    end
    get '/users/not_a_user'
    expect(response).to have_http_status(:not_found)
  end

  it 'shows only public entries, counts and library activity to guests' do
    get user_path(owner)
    expect(response.body).to include('Visible movie', 'Visible review', 'Log in to follow')
    expect(response.body).not_to include('Secret movie', 'Secret review', '1990', 'Edit profile')
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('.library-profile-stats a strong').text).to eq('1')
    get user_path(owner), params: { tab: 'backlog' }
    expect(response.body).not_to include('Secret movie')
  end

  it 'lets owners see private items but removes them from public preview' do
    sign_in(owner)
    get user_path(owner)
    expect(response.body).to include('Secret movie', 'Secret review', 'Public preview', 'Edit profile', '1990')
    get user_path(owner), params: { preview: 'public' }
    expect(response.body).not_to include('Secret movie', 'Secret review', '1990', 'Edit profile')
    expect(response.body).to include('Back to your profile')
  end

  it 'finds shared collected items without revealing private library entries' do
    friend = User.create!(name: 'Friend', email: 'friend-profile@example.com', password: 'password123')
    LibraryItem.create!(user: friend, item: public_movie, is_collected: true)
    LibraryItem.create!(user: friend, item: private_movie, is_collected: true)
    sign_in(friend)
    get user_path(owner)
    expect(response.body).to include('1 collected item', 'Follow')
    expect(response.body).not_to include('Secret movie', 'Secret review')
  end

  it 'filters both shelves and preserves unfiltered headline counts' do
    sign_in(owner)
    get user_path(owner), params: { tab: 'collection', type: 'Book' }
    expect(response.body).to include('Try another media type')
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('.library-profile-stats a strong').text).to eq('2')
    get user_path(owner), params: { tab: 'backlog', type: 'Book' }
    expect(response.body).not_to include('Secret movie')
  end

  it 'keeps admin resource links working with usernames' do
    owner.update!(admin: true)
    sign_in(owner)
    get admin_user_path(owner)
    expect(response).to have_http_status(:ok)
  end

  it 'keeps private liked library entries out of public likes' do
    Like.create!(user: owner, likeable: public_entry)
    Like.create!(user: owner, likeable: private_entry)
    get user_path(owner), params: { tab: 'likes' }
    expect(response.body).to include('Visible movie')
    expect(response.body).not_to include('Secret movie', 'Secret review')
  end

  it 'resolves follower lists and edit routes with usernames' do
    get followers_user_path(owner)
    expect(response).to have_http_status(:ok)
    sign_in(owner)
    get edit_user_path(owner)
    expect(response).to have_http_status(:ok)
  end
end
