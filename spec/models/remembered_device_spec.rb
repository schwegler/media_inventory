# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RememberedDevice do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { User.create!(name: 'Synthetic Member', email: 'remember@example.test', password: 'password123') }

  it 'stores a digest, uses independent 256-bit credentials, and fixes absolute expiry' do
    travel_to Time.current.change(usec: 0) do
      device, token = described_class.issue(user)
      other, other_token = described_class.issue(user)
      expect(token.length).to eq(43)
      expect(other_token).not_to eq(token)
      expect(other.id).not_to eq(device.id)
      expect(device.token_digest).to eq(Digest::SHA256.hexdigest(token))
      expect(device.attributes.values).not_to include(token)
      expect(device.expires_at).to eq(30.days.from_now)
      travel 29.days
      expect(described_class.restore("#{device.id}.#{token}")).to be_present
      expect(device.reload.expires_at).to eq(1.day.from_now)
      travel 1.day
      expect(described_class.restore("#{device.id}.#{token}")).to be_nil
    end
  end

  it 'rotates once, accepts concurrent old requests for at most 60 seconds, then rejects replay' do
    device, token = described_class.issue(user)
    stale_snapshot = described_class.find(device.id)
    restored, replacement = described_class.restore("#{device.id}.#{token}")
    expect(restored.id).to eq(device.id)
    expect(replacement).to be_present
    # Force the CAS loser path with a snapshot fetched before the winning write.
    expect(stale_snapshot.restore(token)).to eq([device.reload, nil])
    expect(described_class.restore("#{device.id}.#{token}")).to eq([device, nil])
    expect(described_class.restore("#{device.id}.#{replacement}")).to eq([device, nil])
    travel 61.seconds
    expect(described_class.restore("#{device.id}.#{token}")).to be_nil
    expect(described_class.restore("#{device.id}.#{replacement}").last).to be_present
  end

  it 'rejects malformed, tampered and revoked credentials' do
    device, token = described_class.issue(user)
    [nil, '', '1.bad', "#{device.id}.#{'x' * 43}", "#{device.id}.#{token}.extra"].each do |value|
      expect(described_class.restore(value)).to be_nil
    end
    device.destroy!
    expect(described_class.restore("#{device.id}.#{token}")).to be_nil
  end

  it 'revokes all devices and advances session generation on password change or reset' do
    described_class.issue(user)
    user.update!(password: 'replacement123')
    expect(user.session_generation).to eq(1)
    expect(user.remembered_devices).to be_empty
    described_class.issue(user)
    user.update!(password_digest: BCrypt::Password.create('reset123'))
    expect(user.session_generation).to eq(2)
    expect(user.remembered_devices).to be_empty
  end

  it 'does not reuse session generations across password changes on stale instances' do
    stale_user = User.find(user.id)
    user.update!(password: 'first-password')
    stale_user.update!(password: 'second-password')
    expect(user.reload.session_generation).to eq(2)
  end

  it 'retains devices on profile edits and revokes them on account deletion' do
    device, = described_class.issue(user)
    user.update!(name: 'Edited Member')
    expect(device.reload).to be_present
    user.destroy!
    expect(described_class.exists?(device.id)).to be false
  end
end
