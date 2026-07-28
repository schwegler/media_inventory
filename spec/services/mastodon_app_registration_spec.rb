# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MastodonAppRegistration, type: :service do
  describe '.safe_host?' do
    it 'returns true for a valid public domain' do
      expect(described_class.safe_host?('mastodon.social')).to be true
    end

    it 'returns false for localhost' do
      expect(described_class.safe_host?('localhost')).to be false
    end

    it 'returns false for 127.0.0.1' do
      expect(described_class.safe_host?('127.0.0.1')).to be false
    end

    it 'returns false for private IP addresses' do
      expect(described_class.safe_host?('10.0.0.1')).to be false
      expect(described_class.safe_host?('192.168.1.10')).to be false
      expect(described_class.safe_host?('172.16.5.5')).to be false
    end

    it 'returns false for link-local IP addresses' do
      expect(described_class.safe_host?('169.254.169.254')).to be false
    end

    it 'returns false for blank or invalid hosts' do
      expect(described_class.safe_host?('')).to be false
      expect(described_class.safe_host?(nil)).to be false
      expect(described_class.safe_host?('not_a_valid_hostname_at_all')).to be false
    end
  end
end
