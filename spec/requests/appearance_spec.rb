# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Appearance preferences', type: :request do
  let(:user) { User.create!(name: 'Reader', email: 'reader@example.com', password: 'password') }

  before { post login_path, params: { session: { email: user.email, password: 'password' } } }

  it 'opens appearance preferences from the main Settings entry point' do
    get settings_path
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('h1').text).to eq('Make Trove yours')
    expect(document.at_css('nav[aria-label="Settings"] a[aria-current="page"]')['href']).to eq(settings_appearance_path)
    expect(document.css('select[name="user[theme]"] option').map { |option| option['value'] }).to eq(%w[os light dark])
    expect(document.at_css('select[name="user[accent_theme]"]')).to be_present
    expect(document.at_css('select[name="user[profile_accent]"]')).to be_present

    get settings_basic_info_path
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('input[name="user[username]"]')).to be_present
  end

  it 'persists global preferences and renders them before styles load' do
    patch settings_appearance_path, params: { user: { theme: 'dark', accent_theme: 'moss', content_density: 'compact',
                                                      media_layout: 'rows', reduce_effects: true } }
    expect(response).to redirect_to(settings_appearance_path)
    get movies_path
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('html')['data-theme']).to eq('dark')
    expect(document.at_css('html')['data-accent']).to eq('moss')
    expect(document.at_css('html')['data-media-layout']).to eq('rows')
    expect(user.reload.reduce_effects).to be true
  end

  it 'scopes another member’s profile preferences to their profile' do
    other = User.create!(name: 'Other', password: 'password', profile_accent: 'moss', profile_header: 'solid')
    get user_path(other)
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('html')['data-accent']).to eq('violet')
    expect(document.at_css('.profile-page')['data-profile-accent']).to eq('moss')
    expect(document.at_css('.profile-page')['data-profile-header']).to eq('solid')
  end

  it 'persists safe profile presets and ignores privilege fields' do
    patch settings_appearance_path, params: { user: { profile_accent: 'ink', profile_header: 'minimal', admin: true } }
    expect(user.reload.profile_accent).to eq('ink')
    expect(user.profile_header).to eq('minimal')
    expect(user.admin?).to be false
    patch settings_appearance_path, params: { user: { profile_accent: '<script>', theme: 'unsafe' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.profile_accent).to eq('ink')
  end

  it 'requires authentication to save preferences' do
    delete logout_path
    patch settings_appearance_path, params: { user: { theme: 'dark' } }
    expect(response).to redirect_to(login_url)
    expect(user.reload.theme).to eq('os')
  end
end
