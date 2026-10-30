# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Halloween appearance', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # Keep the reusable campaign covered independently of the retired live configuration.
  before do
    config = SeasonalHelper::SEASON_CONFIG.deep_dup
    config['activeSeason'] = 'halloween-2026'
    config['seasons'].first['enabled'] = true
    stub_const('SeasonalHelper::SEASON_CONFIG', config)
  end

  it 'accepts independent Halloween profile and account choices without changing existing preferences' do
    user = User.new(name: 'Seasonal reader', password: 'password123')
    expect(user).to be_valid
    user.assign_attributes(accent_theme: 'halloween', profile_accent: 'halloween', profile_header: 'halloween')
    expect(user).to be_valid
    expect(user.theme).to eq('os')
    expect(user.content_density).to eq('comfortable')
    expect(user.media_layout).to eq('covers')
    expect(user.reduce_effects).to be(false)
  end

  it 'offers the invitation only within the fixed 2026 UTC campaign' do
    [Time.utc(2026, 10, 18), Time.utc(2026, 10, 31, 23, 59, 59)].each do |instant|
      travel_to(instant) do
        get root_path
        expect(Nokogiri::HTML(response.body).at_css('body')['data-controller'].split).to include('halloween')
      end
    end
    [Time.utc(2026, 10, 17, 23, 59, 59), Time.utc(2026, 11, 1), Time.utc(2027, 10, 20)].each do |instant|
      travel_to(instant) do
        get root_path
        config = JSON.parse(Nokogiri::HTML(response.body).at_css('body')['data-halloween-config-value'])
        expect(config['seasons'].first['window']['until']).to eq('2026-11-01T00:00:00Z')
        expect(controller.helpers.active_season).to be_nil
      end
    end
  end
  it 'consolidates appearance controls in one accessible header menu' do
    travel_to(Time.utc(2026, 10, 20)) do
      get root_path
      doc = Nokogiri::HTML(response.body)
      menu = doc.at_css('details.appearance-menu')
      expect(menu.css('input[name="base-mode"]').map { |input| input['value'] }).to eq(%w[os light dark])
      expect(menu.text).to include('Seasonal theme', 'Undo Halloween', 'Pause motion', 'Hide atmosphere')
      expect(doc.css('.seasonal-controls').size).to eq(1)
      expect(doc.at_css('.halloween-invitation .seasonal-notice')).to be_nil
      expect(doc.at_css('.halloween-invitation').text).not_to include('Undo', 'Pause')
    end
  end
  it 'persists the approved Halloween night preset independently of base and shelf choices' do
    user = User.create!(name: 'Theme reader', email: 'theme@example.com', password: 'password123')
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    get settings_appearance_path
    expect(response.body).to include('Halloween night', 'user[seasonal_theme]')
    patch settings_appearance_path, params: { user: { seasonal_theme: 'halloween' } }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['preferences']['seasonalTheme']).to eq('halloween')
    expect(user.reload.seasonal_theme).to eq('halloween')
    expect(user.theme).to eq('os')
    expect(user.accent_theme).to eq('violet')
    expect(user.shelf_previews).to be_empty
    travel_to(Time.utc(2027, 2, 1)) do
      get settings_appearance_path
      expect(Nokogiri::HTML(response.body).at_css('input[value="halloween"][name="user[seasonal_theme]"]')['checked'])
        .to be_present
    end
    patch settings_appearance_path, params: { user: { seasonal_theme: 'unapproved' } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.seasonal_theme).to eq('halloween')
  end
end
