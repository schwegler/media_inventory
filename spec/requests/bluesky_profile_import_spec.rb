# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bluesky identity import', type: :request do
  let(:did) { 'did:plc:synthetic-profile' }
  let(:endpoint) { 'https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile' }
  let(:profile) { { did: did, handle: 'reader.example.test', displayName: '読書家 🌙', avatar: 'https://invalid.example/avatar.png' } }

  before do
    OmniAuth.config.test_mode = true
    # Real omniauth-atproto 0.1.4 supplies did/pds_host, not name/nickname.
    OmniAuth.config.mock_auth[:atproto] = OmniAuth::AuthHash.new(
      provider: 'atproto', info: { did: did, pds_host: 'https://pds.example.test' },
      credentials: { token: 'synthetic-token', refresh_token: 'synthetic-refresh' }
    )
    stub_request(:get, endpoint).with(query: { actor: did }).to_return(
      status: 200, body: profile.to_json, headers: { 'Content-Type' => 'application/json' }
    )
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth.delete(:atproto)
  end

  def sign_in
    get '/auth/atproto/callback'
    expect(response).to redirect_to(root_path)
    User.find_by!(bsky_did: did)
  end

  it 'imports the public name and handle from a DID-only OAuth payload' do
    user = sign_in
    expect(user.name).to eq('読書家 🌙')
    expect(user.bsky_handle).to eq('reader.example.test')
    expect(user.username).to eq('reader')
    expect(user.avatar).not_to be_attached
    expect(a_request(:get, profile[:avatar])).not_to have_been_made
  end

  it 'preserves manual profile fields and URL while refreshing the same DID handle' do
    user = sign_in
    user.update!(name: 'My chosen name', username: 'my_library', bio: 'My chosen bio')
    profile[:handle] = 'renamed.example.test'
    stub_request(:get, endpoint).with(query: { actor: did }).to_return(status: 200, body: profile.to_json)
    expect { sign_in }.not_to change(User, :count)
    expect(user.reload.attributes.slice('name', 'username', 'bio', 'bsky_handle')).to eq(
      'name' => 'My chosen name', 'username' => 'my_library', 'bio' => 'My chosen bio',
      'bsky_handle' => 'renamed.example.test'
    )
  end

  it 'keeps existing identity on a network failure' do
    user = sign_in
    stub_request(:get, endpoint).with(query: { actor: did }).to_timeout
    sign_in
    expect(user.reload.bsky_handle).to eq('reader.example.test')
    expect(user.name).to eq('読書家 🌙')
  end

  it 'allows initial login when optional profile fields are missing' do
    stub_request(:get, endpoint).with(query: { actor: did }).to_return(status: 200, body: { did: did }.to_json)
    expect(sign_in.name).to eq(did)
  end

  it 'does not import another DID profile' do
    payload = profile.merge(did: 'did:plc:someone-else')
    stub_request(:get, endpoint).with(query: { actor: did }).to_return(status: 200, body: payload.to_json)
    expect(sign_in.name).to eq(did)
  end

  it 'bounds long Unicode names to the Trove validation limit' do
    stub_request(:get, endpoint).with(query: { actor: did }).to_return(status: 200,
                                                                       body: profile.merge(displayName: '猫' * 60).to_json)
    expect(sign_in.name).to eq('猫' * 50)
  end

  it 'does not keep another DID handle when reconnecting to a different identity during an outage' do
    user = sign_in
    user.update!(name: 'Chosen name', username: 'chosen_library')
    other_did = 'did:plc:synthetic-other'
    OmniAuth.config.mock_auth[:atproto].info.did = other_did
    stub_request(:get, endpoint).with(query: { actor: other_did }).to_timeout
    get '/auth/atproto/callback'
    expect(user.reload.bsky_did).to eq(other_did)
    expect(user.bsky_handle).to eq(other_did)
    expect(user.name).to eq('Chosen name')
    expect(user.username).to eq('chosen_library')
  end

  it 'does not fetch broken remote artwork or replace manually attached artwork' do
    user = sign_in
    user.avatar.attach(io: StringIO.new('synthetic image'), filename: 'chosen.png', content_type: 'image/png')
    avatar_id = user.avatar.blob.id
    sign_in
    expect(user.reload.avatar.blob.id).to eq(avatar_id)
    expect(user.bio).to be_blank
    expect(user.bsky_post_activity).to be false
    expect(user.bsky_post_reviews).to be false
    expect(a_request(:get, profile[:avatar])).not_to have_been_made
  end
end
