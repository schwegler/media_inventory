# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChildCreditsHelper, type: :helper do
  describe '#resolve_raw_credits' do
    it 'returns empty hash when credits is blank or empty' do
      expect(helper.resolve_raw_credits([])).to eq({})
      expect(helper.resolve_raw_credits(nil)).to eq({})
    end

    it 'resolves provider identity first even if another entity shares the same normalized name' do
      MetadataEntity.create!(name: 'Alex Ross', kind: 'person', identity_key: 'person:cv:1')
      person2 = MetadataEntity.create!(name: 'Alex Ross', kind: 'person', identity_key: 'person:cv:2')
      MetadataIdentity.create!(metadata_entity: person2, provider: 'ComicVine:contributor', external_id: '4050-123')

      raw_credit = {
        'name' => 'Alex Ross',
        'provider' => 'ComicVine:contributor',
        'external_id' => '4050-123',
        'role' => 'Cover artist'
      }

      resolved = helper.resolve_raw_credits([raw_credit])
      expect(resolved[raw_credit]).to eq(person2)
    end

    it 'resolves by name when there is exactly one unambiguous entity' do
      person = MetadataEntity.create!(name: 'Unique Author', kind: 'person')

      raw_credit = { 'name' => 'Unique Author', 'role' => 'Author' }

      resolved = helper.resolve_raw_credits([raw_credit])
      expect(resolved[raw_credit]).to eq(person)
    end

    it 'leaves credit unlinked (nil) when name matching is ambiguous (multiple entities share name)' do
      MetadataEntity.create!(name: 'John Smith', kind: 'person', identity_key: 'person:a:1')
      MetadataEntity.create!(name: 'John Smith', kind: 'person', identity_key: 'person:a:2')

      raw_credit = { 'name' => 'John Smith', 'role' => 'Writer' }

      resolved = helper.resolve_raw_credits([raw_credit])
      expect(resolved[raw_credit]).to be_nil
    end

    it 'leaves credit unlinked when no matching entity exists' do
      raw_credit = { 'name' => 'Unknown Person', 'role' => 'Writer' }

      resolved = helper.resolve_raw_credits([raw_credit])
      expect(resolved[raw_credit]).to be_nil
    end
  end
end
