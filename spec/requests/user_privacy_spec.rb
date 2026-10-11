# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Profile Privacy', type: :request do
  let(:owner) { User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner') }
  let(:visitor) do
    User.create!(name: 'Visitor', email: 'visitor@example.com', password: 'password', username: 'visitor')
  end
  let(:movie) { Movie.create!(title: 'Collected Movie') }
  let!(:library_item) do
    LibraryItem.create!(user: owner, item: movie, is_collected: true, is_public: false, review: 'Hidden thoughts')
  end

  before do
    post login_path, params: { session: { email: visitor.email, password: 'password' } }
  end

  it 'shows collected items to other users even when the review is private' do
    get user_path(owner)
    expect(response.body).to include('Collected Movie')
  end

  it 'hides private review content from other users' do
    get user_path(owner)
    expect(response.body).not_to include('Hidden thoughts')
  end

  it 'shows private reviews to the owner' do
    post login_path, params: { session: { email: owner.email, password: 'password' } }
    get user_path(owner)
    expect(response.body).to include('Collected Movie', 'Hidden thoughts')
  end
end
