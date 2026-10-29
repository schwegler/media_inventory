# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public catalog discovery', type: :system do
  before do
    @user = User.create!(name: 'Synthetic Listener', email: 'discovery-ui@example.com', password: 'password',
                         confirmed_at: Time.current)
    @artists = { '777' => 'Charli xcx', '778' => 'Madonna', '779' => 'Buckethead' }
    stub_request(:get, /itunes.apple.com.*search/).to_return do |request|
      query = CGI.parse(request.uri.query)['term'].first.to_s
      id, artist = @artists.find { |_key, name| query.start_with?(name) } || @artists.first
      { body: { results: [{ collectionId: id.to_i, collectionName: 'Synthetic discovery album', artistName: artist,
                            releaseDate: '2024-01-01', collectionViewUrl: "https://music.apple.com/us/album/#{id}" }] }.to_json }
    end
    stub_request(:get, /itunes.apple.com.*lookup/).to_return do |request|
      id = CGI.parse(request.uri.query)['id'].first
      { body: { results: [{ collectionId: id.to_i, collectionName: 'Synthetic discovery album',
                            artistName: @artists[id] }] }.to_json }
    end
  end

  def search_albums(query)
    visit search_path(q: query, type: 'albums')
    expect(page).to have_css('.discovery-result', text: 'Synthetic discovery album')
  end

  it 'lets a guest discover, refine, sign in and review the selected album without restarting' do
    visit root_path
    expect(page).to have_text('Search first. Sign in to collect.')
    capture_ui_screenshot('discovery-synthetic-home-desktop')
    fill_in 'Find something you love', with: 'Charli xcx'
    within '.home-discovery-search' do
      click_button 'Search'
    end
    expect(page).to have_link('Search music (albums)')
    click_link 'Search music (albums)'
    expect(page).to have_text('Available to import · itunes')
    expect(page).to have_text('not complete catalogs or discographies')
    capture_ui_screenshot('discovery-synthetic-albums-desktop')
    [360, 390, 768].each do |width|
      resize_browser_viewport(width, 900)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      capture_ui_screenshot("discovery-synthetic-albums-#{width}")
    end
    find('summary', text: 'Find more matches').click
    fill_in 'Refine your search', with: 'Charli xcx Synthetic discovery album'
    click_button 'Search again'
    expect(page).to have_field('Search media', with: 'Charli xcx Synthetic discovery album')
    expect(URI.decode_www_form(URI.parse(page.current_url).query).to_h).to include(
      'q' => 'Charli xcx Synthetic discovery album', 'type' => 'albums'
    )
    button = find_button('Sign in to import and add: Synthetic discovery album')
    button.send_keys(:enter)
    expect(page).to have_current_path(login_path)
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'wrong'
    click_button 'Log in'
    expect(page).to have_text('Invalid email/password combination.')
    page.driver.browser.logs.get(:browser) # The failed login intentionally returns HTTP 422.
    expect(page).to have_text('Your selection is saved')
    click_link 'Start your vault →'
    expect(page).to have_current_path(signup_path)
    expect(page).to have_text('Claim Your Shelf in Trove')
    expect(page).to have_text('Your selection is saved')
    click_link 'Log in →'
    expect(page).to have_current_path(login_path)
    expect(page).to have_text('Unlock Your Media Vault')
    expect(page).to have_no_css('html[data-turbo-preview]')
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in'
    expect(page).to have_text('Synthetic discovery album')
    expect(page).to have_button('Confirm and save', disabled: false)
    expect(page).to have_link('Back to discovery results')
    resize_browser_viewport(390, 844)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    expect(Album.count).to eq(0)
    expect(LibraryItem.count).to eq(0)
    capture_ui_screenshot('discovery-synthetic-confirmation-mobile')
    click_link 'Back to discovery results'
    expect(page).to have_field('Refine your search', visible: :all, with: 'Charli xcx Synthetic discovery album')
    expect(page).to have_button('Review import and add: Synthetic discovery album')
    expect(page.driver.browser.logs.get(:browser).select { |log| log.level == 'SEVERE' }).to be_empty
  end

  it 'shows the local/import boundary for all three artists and keeps search usable with keyboard and zoom' do
    ['Madonna', 'Buckethead', 'Charli xcx'].each do |artist|
      Album.create!(title: "Synthetic local #{artist}", artist: artist)
      search_albums(artist)
      expect(page).to have_text("Synthetic local #{artist}")
      expect(page).to have_css('.discovery-result', text: artist)
      expect(page).to have_text('In Trove')
      expect(page).to have_text('Available to import')
    end
    page.execute_script('document.documentElement.style.zoom = "2"')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    capture_ui_screenshot('discovery-synthetic-zoom-200')
    page.execute_script('document.documentElement.style.zoom = "1"')
    page.go_back
    expect(page).to have_current_path(search_path(q: 'Buckethead', type: 'albums'))
    expect(page).to have_css('.discovery-result', text: 'Synthetic discovery album')
    page.go_forward
    expect(page).to have_current_path(search_path(q: 'Charli xcx', type: 'albums'))
    expect(Album.count).to eq(3)
    expect(LibraryItem.count).to eq(0)
  end

  it 'distinguishes unavailable catalogs from completed zero results and retains local matches' do
    Album.create!(title: 'Synthetic local Madonna', artist: 'Madonna')
    stub_request(:get, /itunes.apple.com/).to_return(status: 429)
    visit search_path(q: 'Madonna', type: 'albums')
    expect(page).to have_text('Some catalogs could not be searched')
    expect(page).to have_text('Synthetic local Madonna')
    expect(page).to have_button('Retry catalog search')
    capture_ui_screenshot('discovery-synthetic-provider-unavailable')
    stub_request(:get, /itunes.apple.com/).to_return(body: { results: [] }.to_json)
    visit search_path(q: 'A different synthetic query', type: 'albums')
    expect(page).to have_text('No additional titles to import')
    expect(page).not_to have_button('Sign in to import and add')
  end

  it 'imports once on explicit confirmation and keeps the query when login is interrupted' do
    search_albums('Buckethead')
    click_button 'Sign in to import and add: Synthetic discovery album'
    expect(page).to have_current_path(login_path)
    click_link 'Back to results for Buckethead'
    expect(page).to have_current_path(search_path(q: 'Buckethead', type: 'albums'))
    click_button 'Sign in to import and add: Synthetic discovery album'
    fill_in 'Email', with: @user.email
    fill_in 'Password', with: 'password'
    click_button 'Log in'
    expect(page).to have_button('Confirm and save', disabled: false)
    expect(Album.count).to eq(0)
    check 'In Collection'
    click_button 'Confirm and save'
    expect(page).to have_text('Album was successfully logged')
    expect(Album.where(api_id: 'itunes_779').count).to eq(1)
    expect(@user.library_items.count).to eq(1)
    visit search_path(q: 'Buckethead', type: 'albums')
    expect(page).to have_text('In Trove · In your library')
    expect(page).not_to have_button('Review import and add: Synthetic discovery album')
  end

  it 'keeps successful partial results visible and ignores obsolete requests' do
    allow(MediaSearchService).to receive(:request).and_call_original
    allow(MediaSearchService).to receive(:request).with('Madonna', 'album', anything).and_return(
      { state: 'pending', results: [{ title: 'Synthetic partial album', api_id: 'itunes_888', source: 'itunes' }] },
      { state: 'ready', results: [{ title: 'Synthetic partial album', api_id: 'itunes_888', source: 'itunes' }] }
    )
    visit search_path(q: 'Madonna', type: 'albums')
    expect(page).to have_text('Synthetic partial album')
    visit search_path(q: 'Buckethead', type: 'albums')
    expect(page).to have_text('Synthetic discovery album')
    expect(page).not_to have_text('Synthetic partial album')
  end
end
