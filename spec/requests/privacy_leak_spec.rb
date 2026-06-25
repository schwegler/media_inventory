# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Privacy Leak', type: :request do
  let(:owner) { User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner') }
  let(:other_user) { User.create!(name: 'Other', email: 'other@example.com', password: 'password', username: 'other') }
  let(:private_movie) { Movie.create!(title: 'Private Movie', director: 'Secret Director') }

  before do
    LibraryItem.create!(user: owner, item: private_movie, is_public: false)
    # Login as other_user
    post login_path, params: { session: { email: other_user.email, password: 'password' } }
  end

  describe 'Global Search' do
    it 'does not leak private items to other users' do
      get search_path, params: { q: 'Private' }
      expect(response.body).not_to include('Private Movie')
    end
  end

  describe 'Autocomplete' do
    it 'does not leak private items to other users' do
      get media_autocomplete_path, params: { q: 'Private', type: 'movie' }
      json = JSON.parse(response.body)
      titles = json.map { |r| r['title'] }
      expect(titles).not_to include('Private Movie')
    end
  end
end
