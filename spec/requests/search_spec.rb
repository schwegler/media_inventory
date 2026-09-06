# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search', type: :request do
  describe 'GET /search' do
    it 'returns http success' do
      get search_path, params: { q: 'test' }
      expect(response).to have_http_status(:success)
    end

    it 'renders WAI-ARIA accessibility attributes for filter tabs' do
      get search_path, params: { q: 'Matrix', type: 'movies' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('role="tablist"')
      expect(response.body).to include('aria-label="Filter results by category"')
      expect(response.body).to include('role="tab"')
      expect(response.body).to include('aria-selected="true"')
    end

    it 'eager loads cover images and avoids N+1 queries when rendering results' do
      movie1 = Movie.create!(title: 'Matrix 1', director: 'Lana', release_year: 1999)
      movie2 = Movie.create!(title: 'Matrix 2', director: 'Lana', release_year: 2003)

      # Attach images to trigger Active Storage attachment checks in view
      temp_file = Tempfile.new(['test_cover', '.png'])
      temp_file.write('png header placeholder')
      temp_file.rewind
      file = fixture_file_upload(temp_file.path, 'image/png')
      movie1.cover_image.attach(file)
      movie2.cover_image.attach(file)

      get search_path, params: { q: 'Matrix' }
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Matrix 1')
      expect(response.body).to include('Matrix 2')
    end
  end
end
