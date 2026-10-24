# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Landing page hero and companion bridge redesign', type: :request do
  let!(:user) do
    User.create!(
      name: 'Collector Jane',
      email: 'jane@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  describe 'guest landing page' do
    it 'offers a short value proposition, one primary search and an honest empty-art fallback' do
      get root_path
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at_css('#home-title').text).to eq('A shelf for everything you love.')
      expect(page.at_css('.home-hero-copy > p').text)
        .to include('Collect, track and share games, music, books, movies, TV and comics.')
      expect(page.css('.home-discovery-search input[type="search"]').size).to eq(1)
      expect(page.at_css('.home-actions a')['href']).to eq(signup_path)
      expect(page.at_css('.home-actions a').text).to eq('Create your shelf')
      expect(page.at_css('.home-hero-visual-empty')).to be_present
      expect(page.css('.home-cover')).to be_empty
      expect(page.at_css('.home-hero-mascot img')['src']).to include('brand/facet_pose_01_bookworm')
    end

    it 'keeps the blog link without a competing promotional panel' do
      get root_path
      page = Nokogiri::HTML(response.body)
      expect(page.at_css('.home-blog')).to be_nil
      expect(page.at_css('.home-blog-link a')['href']).to eq('https://tacobout.online/')
    end

    it 'reveals coverage and community details on demand rather than showing an instruction list' do
      get root_path
      page = Nokogiri::HTML(response.body)
      expect(page.at_css('.home-catalog-note')['open']).to be_nil
      expect(page.at_css('.home-catalog-note').text).to include('In Trove', 'Available to import',
                                                                'Music discovery searches albums')
      expect(page.at_css('.home-community-disclosure')['open']).to be_nil
      expect(page.css('.home-steps')).to be_empty
    end
  end

  describe 'signed-in member dashboard' do
    it 'prioritizes personal library activity without the guest signup hero' do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
      expect(response).to redirect_to(user_path(user))
      get root_path
      expect(response).to have_http_status(:ok)

      page = Nokogiri::HTML(response.body)
      expect(page.at_css('.home-intro')).to be_nil
      expect(page.at_css('.dashboard-welcome')).to be_present
      expect(page.at_css('.dashboard-welcome h1').text).to eq('Continue your story')
    end
  end
end
