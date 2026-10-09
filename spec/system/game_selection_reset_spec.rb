# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Game selection reset', type: :system do
  it 'clears selected identity, artwork and metadata when starting a different manual game' do
    VideoGame.create!(title: 'Catalog selection probe', developer: 'Old developer',
                      publisher: 'Old publisher', platform: 'Old platform', release_year: 2022)
    allow(MediaSearchService).to receive(:call).and_return([])
    create_and_login_user(email: 'selection-reset@example.com')
    visit new_video_game_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'Catalog selection probe'
    find('.thumbnail-option-card', text: 'Catalog selection probe').click
    expect(page).to have_text('Log Details')
    expect(find('input[name="video_game[catalog_selection]"]', visible: :all).value).not_to be_empty
    click_button 'BACK'
    fill_in 'Title', with: 'Another manual game'
    click_button 'Add Manually'
    %w[catalog_selection api_id thumbnail_url developer publisher platform release_year].each do |field|
      expect(find("input[name=\"video_game[#{field}]\"]", visible: :all).value).to eq('')
    end
    expect(page).to have_field('video_game[title]', with: 'Another manual game', visible: :all)
    expect(page).not_to have_css('[data-thumbnail-fetcher-target="previewImg"]')
  end
end
