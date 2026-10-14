# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Global shell brand and navigation', type: :request do
  it 'renders Trove faceted app icon, wordmark, and companion brand link' do
    get root_path
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)

    # Brand link with Trove icon
    brand_link = page.at_css('.app-header .brand-link')
    expect(brand_link).to be_present
    logo = brand_link.at_css('img.brand-logo')
    expect(logo['src']).to include('brand/trove_rounded_app_icon')
    expect(brand_link.text).to include('trove')

    # Companion link to tacobout
    companion = page.at_css('.app-header .brand-companion')
    expect(companion).to be_present
    expect(companion['href']).to eq('https://tacobout.online/')
    expect(companion.text).to include('from taco ’bout it')

    # Footer brand
    footer_logo = page.at_css('.app-footer .footer-logo')
    expect(footer_logo['src']).to include('brand/trove_rounded_app_icon')
    expect(page.at_css('.app-footer').text).to include('A library companion to taco ’bout it.')
  end

  it 'preserves all six media catalog links in the global navigation' do
    get root_path
    page = Nokogiri::HTML(response.body)
    nav_links = page.css('.workspace-primary-nav a').map { |a| [a.text.strip, a['href']] }
    
    expect(nav_links).to include(['Movies', movies_path])
    expect(nav_links).to include(['Albums', albums_path])
    expect(nav_links).to include(['Comics', comics_path])
    expect(nav_links).to include(['TV Shows', tv_shows_path])
    expect(nav_links).to include(['Video Games', video_games_path])
    expect(nav_links).to include(['Books', books_path])
  end
end
