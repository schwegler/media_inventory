# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Albums Pagination', type: :request do
  describe 'GET /albums' do
    before do
      # Create 30 albums
      30.times do |i|
        Album.create!(title: "Album #{i + 1}", artist: "Artist #{i + 1}")
      end
    end

    it 'returns paginated albums' do
      get albums_path
      expect(response).to have_http_status(:success)

      # Should include newest 25 (Album 6 to 30)
      (5...30).each do |i|
        expect(response.body).to include(">Album #{i + 1}</a>")
      end

      # Should NOT include oldest 5 (Album 1 to 5)
      5.times do |i|
        expect(response.body).not_to include(">Album #{i + 1}</a>")
      end

      # Should include pagination links
      expect(response.body).to include('Next')
      expect(response.body).to include('Last')
    end

    it 'returns second page of albums' do
      get albums_path(page: 2)
      expect(response).to have_http_status(:success)

      # Should include oldest 5 (Album 1 to 5)
      5.times do |i|
        expect(response.body).to include(">Album #{i + 1}</a>")
      end

      # Should NOT include newest 25 (Album 6 to 30)
      (5...30).each do |i|
        expect(response.body).not_to include(">Album #{i + 1}</a>")
      end
    end
  end
end
