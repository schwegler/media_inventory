# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Find This Title Links Alignment', type: :request do
  let!(:movie) { Movie.create!(title: 'Dune') }

  it 'renders structured icon, label, and external link layout for all rows' do
    get movie_path(movie)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="media-source-icon"')
    expect(response.body).to include('class="media-source-label"')
    expect(response.body).to include('Find this title')
  end
end
