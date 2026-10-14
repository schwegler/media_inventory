# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branding and metadata assets', type: :request do
  describe 'GET /' do
    it 'renders the full Trove favicon, touch icon, and brand metadata suite' do
      get root_path

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)

      expect(doc.at_css('link[rel="icon"][type="image/svg+xml"]')['href']).to eq('/favicon.svg')
      expect(doc.at_css('link[rel="icon"][sizes="32x32"]')['href']).to eq('/brand/trove_favicon_32px.png')
      expect(doc.at_css('link[rel="icon"][sizes="any"]')['href']).to eq('/favicon.ico')
      expect(doc.at_css('link[rel="apple-touch-icon"]')['href']).to eq('/brand/trove_rounded_app_icon.png')

      expect(doc.at_css('meta[property="og:site_name"]')['content']).to eq('Trove')
      expect(doc.at_css('meta[property="og:description"]')['content']).to include('A home for every story, album, and game')
      twitter_desc = doc.at_css('meta[name="twitter:description"]')['content']
      expect(twitter_desc).to include('A home for every story, album, and game')
      expect(doc.at_css('meta[property="og:image"]')['content']).to end_with('/brand/trove_logo_dark_card.png')

      expect(doc.at_css('meta[name="theme-color"][media="(prefers-color-scheme: light)"]')['content']).to eq('#7C3AED')
      expect(doc.at_css('meta[name="theme-color"][media="(prefers-color-scheme: dark)"]')['content']).to eq('#161320')
    end
  end

  describe 'Favicon and brand asset availability' do
    it 'serves valid physical favicon and app icon assets from public root' do
      expect(File.exist?(Rails.root.join('public/favicon.svg'))).to be true
      expect(File.exist?(Rails.root.join('public/favicon.ico'))).to be true
      expect(File.exist?(Rails.root.join('public/favicon.png'))).to be true
      expect(File.exist?(Rails.root.join('public/apple-touch-icon.png'))).to be true
      expect(File.exist?(Rails.root.join('public/icon.png'))).to be true

      svg = File.read(Rails.root.join('public/favicon.svg'))
      expect(svg).to include('#7C3AED')
      expect(svg).to include('#A855F7')
      expect(svg).to include('#DDD6FE')
    end
  end
end
