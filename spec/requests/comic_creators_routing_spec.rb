# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comic Creators Routing', type: :request do
  let!(:comic) { Comic.create!(title: 'Phang', writer: 'Kieron Gillen', artist: 'Jamie McKelvie') }

  it 'routes comic creator links to entity pages or comic-creators and not music artists' do
    get comic_path(comic)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('/categories/artists/Jamie%20McKelvie')
  end

  it 'shows comic creator titles under comic-creators category show page' do
    get category_item_path(category_type: 'comic-creators', name: 'Jamie McKelvie')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Back to Comic Creators')
    expect(response.body).to include('Phang')
  end
end
