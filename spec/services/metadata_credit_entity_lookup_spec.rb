# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadataCreditEntityLookup do
  def person(id)
    MetadataEntityResolver.call('name' => 'Alex Lee', 'kind' => 'person', 'provider' => 'ComicVine:contributor',
                                'external_id' => id.to_s)
  end

  it 'honors supplied identities when two people share a name' do
    first = person(111)
    person(222)
    row = { 'name' => 'Alex Lee', 'provider' => 'ComicVine:contributor', 'external_id' => 111 }

    expect(described_class.call([row])[row]).to eq(first)
  end

  it 'does not guess between same-name people without an identity' do
    person(111)
    person(222)
    row = { 'name' => 'Alex Lee' }

    expect(described_class.call([row])[row]).to be_nil
  end

  it 'does not replace an unknown provider ID with a different ID from that provider' do
    person(111)
    row = { 'name' => 'Alex Lee', 'provider' => 'ComicVine:contributor', 'external_id' => '222' }

    expect(described_class.call([row])[row]).to be_nil
  end

  it 'uses a unique compatible name and ignores unrelated entity kinds' do
    artist = MetadataEntity.create!(name: 'Phoenix', kind: 'artist')
    MetadataEntity.create!(name: 'Phoenix', kind: 'organization')
    row = { 'name' => ' Phoenix ', 'role' => 'Track artist' }

    expect(described_class.call([row])[row]).to eq(artist)
  end

  it 'matches organization credits without assigning them to people' do
    publisher = MetadataEntity.create!(name: 'Phoenix', kind: 'organization')
    MetadataEntity.create!(name: 'Phoenix', kind: 'person')
    row = { 'name' => 'Phoenix', 'role' => 'publisher' }

    expect(described_class.call([row])[row]).to eq(publisher)
  end

  it 'does not write entities or identities for unknown names' do
    row = { 'name' => 'Unknown creator', 'provider' => 'ComicVine:contributor', 'external_id' => '999' }

    expect do
      expect(described_class.call([row])[row]).to be_nil
    end.not_to(change { [MetadataEntity.count, MetadataIdentity.count] })
  end

  it 'ignores missing names and malformed rows' do
    expect(described_class.call([nil, 'invalid', {}, { 'name' => '' }])).to eq({})
  end
end
