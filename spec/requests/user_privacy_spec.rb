# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Profile Privacy', type: :request do
  let(:owner) { User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner') }
  let(:visitor) do
    User.create!(name: 'Visitor', email: 'visitor@example.com', password: 'password', username: 'visitor')
  end
  let(:movie) { Movie.create!(title: 'Private Movie') }
  let!(:library_item) { LibraryItem.create!(user: owner, item: movie, is_collected: true, is_public: false) }

  before do
    post login_path, params: { session: { email: visitor.email, password: 'password' } }
  end

  it 'does not show private items to other users' do
    get user_path(owner)
    expect(response.body).not_to include('Private Movie')
  end

  it 'shows private items to the owner' do
    post login_path, params: { session: { email: owner.email, password: 'password' } }
    get user_path(owner)
    expect(response.body).to include('Private Movie')
  end
end
