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
    it 'renders redesigned hero headline, copy, and bookworm mascot' do
      get root_path
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      # Hero headline & copy
      expect(page.at_css('#home-title').text).to include('A home for every story, album, and game you’re into.')
      expect(page.at_css('.home-intro-main p').text).to include('Build your shelf across 6 media formats, track active series')

      # CTAs
      signup_btn = page.at_css('.home-actions a.sleek-btn-primary')
      expect(signup_btn['href']).to eq(signup_path)
      expect(signup_btn.text.strip).to eq('Create your library')

      browse_btn = page.at_css('.home-actions a.blog-link')
      expect(browse_btn['href']).to eq(movies_path)
      expect(browse_btn.text).to include('Browse the stacks')

      # Hero mascot
      hero_mascot = page.at_css('.home-hero-mascot img')
      expect(hero_mascot['src']).to include('brand/facet_pose_01_bookworm')
      expect(hero_mascot['class']).to include('mascot-sticker')
    end

    it 'renders companion bridge card with Duo mascot and link to tacobout' do
      get root_path
      page = Nokogiri::HTML(response.body)

      companion = page.at_css('.home-blog')
      expect(companion).to be_present
      expect(companion.at_css('h2').text).to eq('The Vault. The Broadcast.')
      expect(companion.at_css('p').text).to include('Trove stacks the collection; taco ‘bout it brings the hot takes')

      tune_in_link = companion.at_css('a.blog-link')
      expect(tune_in_link['href']).to eq('https://tacobout.online/')
      expect(tune_in_link.text).to include('Tune into the blog')

      duo_mascot = companion.at_css('img')
      expect(duo_mascot['src']).to include('brand/mascot_duo_telly_and_facet_transparent')
      expect(duo_mascot['class']).to include('mascot-sticker')
    end

    it 'renders updated Make It Yours onboarding capabilities' do
      get root_path
      page = Nokogiri::HTML(response.body)

      steps = page.css('.home-steps li').map(&:text)
      expect(steps[0]).to include('Log across 6 formats (Movies, TV, Books, Albums, Comics, Games)')
      expect(steps[1]).to include('Track your backlog & active seasons')
      expect(steps[2]).to include('Drop star ratings that sync to the blog & feed')
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
      expect(page.at_css('.welcome-name').text).to eq('Collector Jane')
    end
  end
end
