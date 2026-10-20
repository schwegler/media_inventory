# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title library action state', type: :system do
  it 'reconciles repeated keyboard toggles, personal flags and like counts without navigating' do
    user = create_and_login_user
    movie = Movie.create!(title: 'Synthetic library state QA')
    library = LibraryItem.create!(user: user, item: movie)
    visit movie_path(movie)
    page.execute_script('window.libraryDocumentMarker = "same-document"')

    { is_collected: :is_collected, in_watchlist: :in_backlog, consumed: :consumed }.each do |field, stored|
      [true, false, true, false].each do |value|
        within('[aria-label="My Library"] .actions-buttons-row') do
          form = find("input[name='movie[#{field}]']", visible: false).find(:xpath, '..')
          form.find('button').send_keys(:enter)
          expect(page).to have_css("input[name='movie[#{field}]'][value='#{!value}']", visible: false)
          button = find("input[name='movie[#{field}]']", visible: false).find(:xpath, '..').find('button')
          expect(button['aria-pressed']).to eq(value.to_s)
          expect(button[:class].include?('is-selected')).to eq(value)
        end
        expect(library.reload.public_send(stored)).to eq(value)
        expect(page.evaluate_script('window.libraryDocumentMarker')).to eq('same-document')
      end
    end

    [true, false, true, false].each do |liked|
      within("#like_button_Movie_#{movie.id}") do
        find('button').send_keys(:space)
        expect(page).to have_css("button[aria-pressed='#{liked}'] .likes-count", text: liked ? '1' : '0', exact_text: true)
      end
      expect(user.liked?(movie)).to eq(liked)
      expect(movie.likes.count).to eq(liked ? 1 : 0)
    end
    page.refresh
    expect(page).to have_button('Watched')
    expect(page).to have_css('[aria-label="My Library"] button[aria-pressed="false"]', count: 4)
  end
end
