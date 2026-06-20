# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MastodonOauthApplication, type: :model do
  it 'is valid with valid attributes' do
    app = MastodonOauthApplication.new(client_id: '123', client_secret: 'secret', domain: 'mastodon.social')
    expect(app).to be_valid
  end
end
