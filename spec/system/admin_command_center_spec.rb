# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin command center interactions', type: :system do
  let!(:admin) do
    User.create!(name: 'Admin reviewer', email: 'browser-admin@example.com', password: 'password123',
                 confirmed_at: Time.current, admin: true)
  end
  let!(:movie) { Movie.create!(title: 'Browser catalog title') }

  before do
    visit login_path
    fill_in 'Email', with: admin.email
    fill_in 'Password', with: 'password123'
    click_button 'Log in'
    expect(page).to have_current_path(user_path(admin))
    visit admin_root_path
    expect(page).to have_css('h1', text: 'Command Center')
  end

  after { page.driver.browser.manage.window.resize_to(1400, 900) }

  it 'focuses global search with the documented keyboard shortcut and follows results' do
    page.driver.browser.action.key_down(:control).send_keys('k').key_up(:control).perform
    expect(page.evaluate_script('document.activeElement.id')).to eq('admin-global-search')
    fill_in 'admin-global-search', with: 'Browser catalog'
    within('.global-admin-search') { click_button 'Search' }
    expect(page).to have_css('h1', text: 'Admin search')
    within('.record-list') { click_link 'Browser catalog title' }
    expect(page).to have_current_path(admin_movie_path(movie))
  end

  it 'keeps phone navigation and media records usable without horizontal overflow' do
    page.driver.browser.manage.window.resize_to(375, 900)
    visit admin_movies_path
    expect(page).to have_css('h1', text: 'Movies')
    expect(page).to have_css('.media-cell', text: movie.title)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    find('summary', text: /Moderation/i).click
    click_link 'Edit suggestions', exact: true
    expect(page).to have_css('h1', text: 'Edit suggestions')
  end

  it 'requires confirmation before applying a suggestion and shows the resulting decision' do
    suggestion = EditSuggestion.create!(user: admin, suggestable: movie, proposed_changes: { title: 'Reviewed title' })
    visit admin_edit_suggestion_path(suggestion)
    dismiss_confirm { click_button 'Approve and apply' }
    expect(movie.reload.title).to eq('Browser catalog title')
    accept_confirm { click_button 'Approve and apply' }
    expect(page).to have_text('Edit suggestion approved and applied.')
    expect(page).to have_text('This suggestion was approved.')
    expect(movie.reload.title).to eq('Reviewed title')
  end
  it 'reviews provider results on a phone and confirms filling missing metadata' do
    allow(MediaSearchService).to receive(:call).and_return([
                                                             { title: 'Provider title', director: 'Provider director',
                                                               external_url: 'https://www.themoviedb.org/movie/45' }
                                                           ])
    page.driver.browser.manage.window.resize_to(375, 900)
    visit search_api_admin_movie_path(movie)
    expect(page).to have_text('Provider title')
    expect(page).to have_link('www.themoviedb.org')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    accept_confirm { click_button 'Fill missing metadata' }
    expect(page).to have_text('Item successfully updated from API data.')
    expect(movie.reload).to have_attributes(title: 'Browser catalog title', director: 'Provider director')
  end
end
