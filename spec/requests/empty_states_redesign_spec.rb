# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog and filter empty states redesign', type: :request do
  let!(:user) do
    User.create!(
      name: 'Gamer Sam',
      email: 'sam@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  describe 'video games empty filter state' do
    it 'renders Mascot Empty-State Card with Gamer Mode Facet and clear actions' do
      get video_games_path
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      card = page.at_css('.mascot-empty-card')
      expect(card).to be_present
      expect(card['role']).to eq('status')

      # Facet gamer mode mascot
      mascot = card.at_css('.empty-state-mascot img')
      expect(mascot['src']).to include('brand/facet_pose_02_gamer_mode')
      expect(mascot['class']).to include('mascot-sticker')

      # Copy
      expect(card.at_css('h2').text).to eq('0 matches in the vault')
      expect(card.at_css('p').text).to include('Even Facet checked the back of the cartridge shelf and came up empty')

      # Actions
      actions = card.css('.empty-state-actions a').map(&:text)
      expect(actions).to include('Clear filters', 'Log a game')
    end
  end

  describe 'media catalog filtered zero-match state' do
    it 'renders Mascot Empty-State Card when searching yields no results' do
      get movies_path, params: { q: 'nonexistent-query-12345' }
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      card = page.at_css('.mascot-empty-card')
      expect(card).to be_present
      expect(card.at_css('h2').text).to eq('0 matches in the vault')
      expect(card.at_css('p').text).to include('No matching titles')

      mascot = card.at_css('.empty-state-mascot img')
      expect(mascot['src']).to include('brand/facet_pose_02_gamer_mode')
      expect(card.at_css('.empty-state-actions a').text).to eq('View all titles')
    end
  end

  describe 'personal empty library state' do
    it 'renders Bookworm Facet when a member has zero logged titles on a shelf' do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
      get movies_path, params: { library: 'mine' }
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      card = page.at_css('.mascot-empty-card')
      expect(card).to be_present
      expect(card.at_css('h2').text).to eq('Your library starts here')

      mascot = card.at_css('.empty-state-mascot img')
      expect(mascot['src']).to include('brand/facet_pose_01_bookworm')
      expect(card.at_css('.empty-state-actions').text).to include('Log a movie')
    end
  end
end
