# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Retired seasonal campaign', type: :request do
  it 'omits the overlay and controls for guests and returning accounts without changing saved preferences' do
    get root_path
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('body')['data-controller'].split).not_to include('halloween')
    expect(doc.css('.halloween-invitation, .seasonal-controls, .seasonal-scene')).to be_empty

    user = User.create!(name: 'Returning reader', email: 'returning@example.com', password: 'password123',
                        seasonal_theme: 'halloween', theme: 'light', accent_theme: 'moss')
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    get settings_appearance_path
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('body')['data-controller'].split).not_to include('halloween')
    expect(doc.css('.halloween-invitation, .seasonal-controls, .seasonal-scene')).to be_empty
    expect(doc.css('input[name="user[seasonal_theme]"]')).to be_empty
    expect(doc.at_css('html')['data-theme']).to eq('light')
    expect(doc.at_css('html')['data-accent']).to eq('moss')
    expect(user.reload.seasonal_theme).to eq('halloween')
    expect(controller.helpers.available_season).to be_nil
    expect(controller.helpers.active_season(now: Time.utc(2026, 10, 20))).to be_nil
    expect(controller.helpers.active_season(now: Time.utc(2026, 12, 20))).to be_nil
  end
end
