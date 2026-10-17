# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Dashboard audiences', type: :request do
  let(:viewer) { User.create!(name: 'Viewer', email: 'audience@example.test', password: 'password123') }
  let(:friend) { User.create!(name: 'Friend', email: 'followed@example.test', password: 'password123') }
  let(:stranger) { User.create!(name: 'Stranger', email: 'stranger@example.test', password: 'password123') }

  def login
    post login_path, params: { session: { email: viewer.email, password: 'password123' } }
  end

  def add(user, title, **values)
    entry = LibraryItem.create!(user: user, item: Movie.create!(title: title), **values)
    Activity.create!(user: user, trackable: entry, activity_type: 'added')
    entry
  end

  it 'shows followed activity without silently mixing in other accounts' do
    viewer.follow(friend)
    add(friend, 'Followed discovery')
    add(stranger, 'Unfollowed discovery')
    login
    get root_path
    expect(response.body).to include('New from friends', 'Followed discovery')
    expect(response.body).not_to include('Unfollowed discovery')
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
  end

  it 'labels the community fallback and hides private rating/review content' do
    entry = add(stranger, 'Public membership', review: 'Hidden review body', rating: '4.5', is_public: false)
    Activity.create!(user: stranger, trackable: entry, activity_type: 'reviewed')
    login
    get root_path
    expect(response.body).to include('New around Trove', 'Public membership')
    expect(response.body).not_to include('Hidden review body')
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('.friend-stars')).to be_empty
    delete logout_path
    get root_path
    expect(response.body).not_to include('Hidden review body')
  end
end
