# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Impact site verification', type: :request do
  let(:snippet) { "<meta name='impact-site-verification' value='58cdbce4-287d-4850-bf2f-0407230f1516'>" }

  it 'renders the exact verification tag once in the homepage head' do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body.scan(snippet).size).to eq(1)
    page = Nokogiri::HTML(response.body)
    tags = page.css('meta[name="impact-site-verification"]')
    expect(tags.size).to eq(1)
    expect(tags.first.parent.name).to eq('head')
    expect(tags.first.attribute_nodes.to_h { |attribute| [attribute.name, attribute.value] })
      .to eq('name' => 'impact-site-verification', 'value' => '58cdbce4-287d-4850-bf2f-0407230f1516')
  end

  it 'keeps verification on the homepage when a query string is present' do
    get root_path, params: { page: 1 }

    expect(response).to have_http_status(:ok)
    expect(response.body.scan(snippet).size).to eq(1)
  end

  it 'includes verification on the member homepage and omits it from account settings' do
    user = User.create!(name: 'Verification Test', email: 'verification@example.test',
                        password: 'password123', password_confirmation: 'password123', confirmed_at: Time.current)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    expect(session[:user_id]).to eq(user.id)

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body.scan(snippet).size).to eq(1)

    get settings_account_path
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('impact-site-verification', '58cdbce4-287d-4850-bf2f-0407230f1516')
  end

  ['/login', '/signup', '/search', '/categories'].each do |path|
    it "omits verification from #{path}" do
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('impact-site-verification', '58cdbce4-287d-4850-bf2f-0407230f1516')
    end
  end
end
