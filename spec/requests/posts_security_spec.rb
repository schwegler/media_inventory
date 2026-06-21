# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Posts Security', type: :request do
  let(:owner) do
    User.create!(name: 'Owner', email: 'owner@example.com', password: 'password', username: 'owner')
  end
  let(:attacker) do
    User.create!(name: 'Attacker', email: 'attacker@example.com', password: 'password', username: 'attacker')
  end
  let(:post_record) { owner.posts.create!(content: 'My private thoughts') }

  before do
    post login_path, params: { session: { email: attacker.email, password: 'password' } }
  end

  it 'prevents accessing another user\'s post' do
    get post_path(post_record)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include('Not authorized')
  end
end
