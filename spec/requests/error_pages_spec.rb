# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '404 Error Page', type: :request do
  it 'serves an on-brand 404 page with Dead air copy, search recovery, and Trove branding' do
    path = Rails.root.join('public/404.html')
    expect(File.exist?(path)).to be true
    html = File.read(path)
    page = Nokogiri::HTML(html)

    expect(page.title).to include('Dead air on this channel')
    expect(page.at_css('h1').text).to eq('Dead air on this channel.')
    expect(page.text).to include('Search the media vault or return to the catalog home.')

    # Facet mascot
    mascot = page.at_css('.mascot-image')
    expect(mascot).to be_present
    expect(mascot['src']).to eq('/brand/facet_pose_01_bookworm.png')

    # Working search form
    search_form = page.at_css('form[action="/search"]')
    expect(search_form).to be_present
    expect(search_form.at_css('input[name="q"]')).to be_present

    # Recovery navigation links
    expect(page.at_css('a[href="/"]')).to be_present
    expect(page.at_css('a[href="https://tacobout.online"]')).to be_present
  end
end
