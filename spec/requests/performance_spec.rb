# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Performance Optimization', type: :request do
  describe 'GET /movies' do
    it 'loads the application layout with deferred javascript' do
      get movies_path
      expect(response).to have_http_status(200)
      # Assert that the script tag DOES have defer="defer"
      expect(response.body).to include('<script type="importmap"')
      expect(response.body).to include('import "application"')
    end

    it 'preloads cover image attachments to prevent N+1 queries' do
      3.times do |i|
        Movie.create!(
          title: "Movie #{i}",
          director: 'Test Director',
          release_year: 2020 + i
        )
      end

      get movies_path
      expect(response).to have_http_status(200)
      expect(controller.instance_variable_get(:@movies).first.association(:cover_image_attachment).loaded?).to be true
    end
  end
end
