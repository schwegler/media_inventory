# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EntityPortraitLookup do
  let!(:entity) { MetadataEntity.create!(name: 'Sample Writer', kind: 'person') }
  let!(:comic) { Comic.create!(title: 'A story') }
  let!(:credit) { MetadataCredit.create!(metadata_entity: entity, item: comic, role: 'Writer', source: 'test') }
  let(:image) { 'https://upload.wikimedia.org/wikipedia/commons/a/ab/Portrait.jpg' }
  let(:summary) do
    { type: 'standard', title: 'Sample Writer', description: 'American writer', thumbnail: { source: image } }
  end
  let(:license) { 'CC BY-SA 4.0' }
  let(:commons) do
    { query: { pages: { '1' => { imageinfo: [{ descriptionurl: 'https://commons.wikimedia.org/wiki/File:Portrait.jpg',
                                               extmetadata: { Artist: { value: '<a>Photographer</a>' },
                                                              LicenseShortName: { value: license } } }] } } } }
  end

  before do
    stub_request(:get, %r{https://en.wikipedia.org/api/rest_v1/page/summary/}).to_return(body: summary.to_json)
    stub_request(:get, %r{https://commons.wikimedia.org/w/api.php}).to_return(body: commons.to_json)
  end

  it 'imports an exact person match with source, credit, and license' do
    described_class.call(entity)
    expect(entity.reload.thumbnail_url).to eq(image)
    expect(entity.portrait_metadata).to include('credit' => 'Photographer', 'license' => license)
  end

  it 'keeps provider artwork' do
    entity.update!(thumbnail_url: 'https://image.tmdb.org/t/p/w185/person.jpg')
    described_class.call(entity)
    expect(entity.reload.thumbnail_url).to include('image.tmdb.org')
    expect(WebMock).not_to have_requested(:get, %r{en.wikipedia.org/api/rest_v1/})
  end

  it 'rejects disambiguation and mismatched identities or professions' do
    [summary.merge(type: 'disambiguation'), summary.merge(title: 'Another Person'),
     summary.merge(description: 'American football player')].each do |payload|
      stub_request(:get, %r{https://en.wikipedia.org/api/rest_v1/page/summary/}).to_return(body: payload.to_json)
      allow(MediaSources::Http).to receive(:cached_get).and_call_original
      allow(MediaSources::Http).to receive(:cached_get).with(/en.wikipedia.org/).and_return(payload.to_json)
      described_class.call(entity)
      expect(entity.reload.thumbnail_url).to be_nil
    end
  end

  it 'leaves missing images alone and tolerates provider errors' do
    allow(MediaSources::Http).to receive(:cached_get).and_raise(MediaSources::Http::Error, 'HTTP 404')
    expect { described_class.call(entity) }.not_to raise_error
    expect(entity.reload.thumbnail_url).to be_nil
  end

  context 'with a noncommercial license' do
    let(:license) { 'CC BY-NC 4.0' }

    it 'keeps the initial fallback' do
      described_class.call(entity)
      expect(entity.reload.thumbnail_url).to be_nil
    end
  end
end
