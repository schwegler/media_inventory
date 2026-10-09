# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comic series search', type: :system do
  after { page.driver.browser.execute_cdp('Emulation.clearDeviceMetricsOverride') }

  it 'finds a specific run, shows its year, and selects its provider identity on desktop and mobile' do
    ApiConfiguration.create!(source_name: 'ComicVine', media_type: 'Comic', is_active: true, access_token: 'test')
    allow_any_instance_of(MetadataProvider).to receive(:call).and_return([{}, {}])
    image = '/favicon.svg'
    volumes = [1963, 1981, 2009, 2012, 2013, 2016, 2024].map do |year|
      { id: year == 2024 ? 159_189 : year, name: 'Uncanny X-Men', start_year: year.to_s,
        publisher: { name: 'Marvel' }, count_of_issues: 36, image: { original_url: image } }
    end
    stub_request(:get, %r{comicvine.gamespot.com/api/search/}).to_return(body: { results: volumes }.to_json)
    stub_request(:get, %r{comicvine.gamespot.com/api/volumes/}).with(
      query: hash_including('filter' => 'name:Uncanny X-Men', 'sort' => 'date_added:desc')
    ).to_return(body: { results: [volumes.last] }.to_json)

    create_and_login_user(email: 'comic-search@example.com')
    visit new_comic_path
    expect(page).to have_css('[data-connected="true"]')
    fill_in 'Title', with: 'Uncanny X-Men'
    expect(page).to have_css('.thumbnail-option-card', count: 7)
    expect(first('.thumbnail-option-card')).to have_text('Started 2024')
    expect(first('.thumbnail-option-card')).to have_text('Marvel · 36 issues')
    expect(page.title).to be_present

    fill_in 'Series start year (optional)', with: '2024'
    expect(page).to have_css('.thumbnail-option-card', count: 1)
    expect(page).not_to have_text('Started 2016')
    page.current_window.resize_to(390, 844)
    page.driver.browser.execute_cdp('Emulation.setDeviceMetricsOverride',
                                    width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    expect(page).to have_css('.option-series-year', text: 'Started 2024')
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be(true)

    find('.thumbnail-option-card').click
    expect(page).to have_text('Uncanny X-Men (2024)')
    expect(page).to have_field('comic[title]', with: 'Uncanny X-Men (2024)', visible: :all)
    expect(find('input[name="comic[api_id]"]', visible: :all).value).to eq('159189')
    expect(page).to have_field('Publisher', with: 'Marvel')
  end
end
