# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Video Game Dedicated Workspace', type: :request do
  let(:user) { User.create!(name: 'Samus Aran', email: 'samus@example.com', password: 'password123') }
  let(:other) { User.create!(name: 'Ridley', email: 'ridley@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Metroid Prime', platform: 'GameCube', developer: 'Retro Studios') }
  let!(:library) { LibraryItem.create!(user: user, item: game, is_collected: true, is_public: true) }

  before do
    library.game_copies.create!(platform: 'Nintendo Switch', storefront: 'eShop', access_method: 'digital')
    playthrough = library.game_playthroughs.create!(platform: 'Nintendo Switch', status: 'completed', progress: 100)
    playthrough.game_sessions.create!(started_at: 2.hours.ago, ended_at: Time.current,
                                      notes: 'Phendrana Drifts exploration')
    library.game_journal_entries.create!(body: 'Found the Thermal Visor.', spoiler: true)
    library.game_milestones.create!(title: 'Defeat Thardus', completed_at: Time.current)
  end

  context 'when signed in as the game owner' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    it 'renders the 6-section workspace navigation and dedicated cards' do
      get video_game_path(game)
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      # Subnav links for workspace
      nav = page.at_css('.media-section-nav')
      expect(nav).to be_present
      expect(nav.at_css('a[href="#overview"]')).to be_present
      expect(nav.at_css('a[href="#my-game-tracking"]')).to be_present
      expect(nav.at_css('a[href="#game-copies"]')).to be_present
      expect(nav.at_css('a[href="#game-playthroughs"]')).to be_present
      expect(nav.at_css('a[href="#game-journal"]')).to be_present
      expect(nav.at_css('a[href="#game-artwork"]')).to be_present
      expect(nav.at_css('a[href="#game-tools"]')).to be_present

      # Workspace section anchors
      expect(page.at_css('#game-copies')).to be_present
      expect(page.at_css('#game-playthroughs')).to be_present
      expect(page.at_css('#game-journal')).to be_present
      expect(page.at_css('#game-milestones')).to be_present
      expect(page.at_css('#game-artwork')).to be_present
      expect(page.at_css('#game-tools')).to be_present

      # Content verification
      expect(response.body).to include('Phendrana Drifts exploration')
      expect(response.body).to include('Found the Thermal Visor.')
      expect(response.body).to include('Defeat Thardus')
      expect(response.body).to include('These are your manual goals, separate from platform achievements')
    end
  end

  context 'when visited by another user' do
    before do
      post login_path, params: { session: { email: other.email, password: 'password123' } }
    end

    it 'protects private workspace data and does not render personal tracking sections' do
      get video_game_path(game)
      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)

      expect(response.body).not_to include('Phendrana Drifts exploration')
      expect(response.body).not_to include('Found the Thermal Visor.')
      expect(response.body).not_to include('Defeat Thardus')
      expect(page.at_css('#game-copies')).to be_nil
      expect(page.at_css('#game-playthroughs')).to be_nil
      expect(page.at_css('#game-journal')).to be_nil
      expect(page.at_css('#game-milestones')).to be_nil
      expect(page.at_css('#game-tools')).to be_nil
    end
  end
end
