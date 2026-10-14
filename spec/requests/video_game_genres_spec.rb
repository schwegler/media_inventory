# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Video Game Genre Pills', type: :request do
  let!(:game) do
    VideoGame.create!(
      title: 'Hades',
      developer: 'Supergiant Games',
      platform: 'PC',
      metadata_details: { 'genres' => %w[Roguelike Action] }
    )
  end

  it 'renders genre pills as links on video game show page' do
    get video_game_path(game)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('/categories/genres/Roguelike')
    expect(response.body).to include('/categories/genres/Action')
    expect(response.body).to include('class="category-pill"')
  end

  it 'lists game on genre category page' do
    get category_item_path(category_type: 'genres', name: 'Roguelike')
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Hades')
  end
end
