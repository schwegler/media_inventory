# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication screens redesign', type: :request do
  let!(:user) do
    User.create!(
      name: 'Vault Member',
      email: 'member@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  describe 'GET /login' do
    it 'renders redesigned login header, five-star Facet mascot, and vault prompt' do
      get login_path
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(page.at_css('h1').text).to eq('Unlock Your Media Vault')
      expect(page.at_css('.auth-subtitle').text).to include('Sign in with your Fediverse handle (Bluesky / Mastodon)')

      mascot = page.at_css('.auth-mascot img')
      expect(mascot['src']).to include('brand/facet_pose_04_five_star')
      expect(mascot['class']).to include('mascot-sticker')

      # Fediverse and email tabs
      tabs = page.css('.auth-tab').map(&:text)
      expect(tabs).to include('Email', 'Bluesky', 'Mastodon')

      # Signup prompt
      prompt = page.at_css('.auth-signup-prompt')
      expect(prompt.text).to include('Need a shelf?')
      expect(prompt.at_css('a')['href']).to eq(signup_path)
      expect(prompt.at_css('a').text).to include('Start your vault')
    end

    it 'successfully logs in with valid email credentials' do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
      expect(response).to redirect_to(user_path(user))
    end
  end

  describe 'GET /signup' do
    it 'renders redesigned signup header, bookworm Facet mascot, and login prompt' do
      get signup_path
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(page.at_css('h1').text).to eq('Claim Your Shelf in Trove')
      expect(page.at_css('.auth-subtitle').text).to include('Create a free library with Bluesky, Mastodon, or Email')

      mascot = page.at_css('.auth-mascot img')
      expect(mascot['src']).to include('brand/facet_pose_01_bookworm')
      expect(mascot['class']).to include('mascot-sticker')

      # Fediverse tabs
      tabs = page.css('.auth-tab').map(&:text)
      expect(tabs).to include('Email', 'Bluesky', 'Mastodon')

      # Login prompt
      prompt = page.at_css('.auth-signup-prompt')
      expect(prompt.text).to include('Already archiving?')
      expect(prompt.at_css('a')['href']).to eq(login_path)
      expect(prompt.at_css('a').text).to include('Log in')
    end

    it 'creates a new user successfully' do
      expect do
        post users_path, params: {
          user: {
            name: 'New Archivist',
            email: 'archivist@example.com',
            password: 'password123',
            password_confirmation: 'password123'
          }
        }
      end.to change(User, :count).by(1)

      created_user = User.find_by(email: 'archivist@example.com')
      expect(response).to redirect_to(created_user)
    end
  end
end
