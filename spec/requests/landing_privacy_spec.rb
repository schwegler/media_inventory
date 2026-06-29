# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Landing Page Privacy', type: :request do
  let(:owner) do
    User.create!(name: 'Owner', email: 'owner@example.com', password: 'password',
                 username: 'owner', confirmed_at: Time.current)
  end
  let(:visitor) do
    User.create!(name: 'Visitor', email: 'visitor@example.com', password: 'password',
                 username: 'visitor', confirmed_at: Time.current)
  end
  let(:movie) { Movie.create!(title: 'Private Movie') }
  let!(:library_item) { LibraryItem.create!(user: owner, item: movie, is_collected: true, is_public: false) }

  describe 'unauthenticated access' do
    it 'does not show activities for private items in public feed' do
      get root_path
      expect(response.body).not_to include('Private Movie')
    end
  end

  describe 'authenticated access' do
    before do
      post login_path, params: { session: { email: visitor.email, password: 'password' } }
    end

    it 'does not show activities for private items in friend feed' do
      get root_path
      expect(response.body).not_to include('Private Movie')
    end
  end
end
