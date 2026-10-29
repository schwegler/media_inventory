# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'People discovery scope', type: :request do
  let!(:movie) { Movie.create!(title: 'Catalog movie', actors: 'Olivia Wilde', director: 'Olivia Wilde') }
  let(:person) { movie.metadata_entities.find_by!(kind: 'person') }

  it 'renders imported movies and combines roles without duplicating works' do
    get metadata_entity_path(person, library: 'all', media_type: 'Movie')
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('.entity-work-row').size).to eq(1)
    expect(doc.css('.entity-work-role').text).to include('Actor', 'Director')
    expect(doc.css('.entity-credit-summary').text).to include('1 credited work')
  end

  it 'explains an empty personal movie filter and preserves filters in catalog recovery' do
    user = User.create!(name: 'Viewer', email: 'viewer@example.com', password: 'password', confirmed_at: Time.current)
    other = User.create!(name: 'Other', email: 'other@example.com', password: 'password', confirmed_at: Time.current)
    LibraryItem.create!(user: other, item: movie, is_collected: true, review: 'Private review', rating: 3)
    post login_path, params: { session: { email: user.email, password: 'password' } }
    expect do
      get metadata_entity_path(person, library: 'mine', media_type: 'Movie', role: 'Actor', page: 9)
    end.not_to(change(LibraryItem, :count))
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
    expect(response.body).to include('No matching works in your library')
    link = Nokogiri::HTML(response.body).at_css('.home-empty-state a')['href']
    expect(link).to eq(metadata_entity_path(person, library: 'all', media_type: 'Movie', role: 'Actor'))
    expect(response.body).not_to include('Catalog movie', 'Private review')
    get link
    expect(response.body).to include('Catalog movie')
    expect(response.body).not_to include('Private review')
    get metadata_entity_path(person, library: 'mine', media_type: 'Book')
    expect(response.body).not_to include('View matching works in All Trove')
  end

  it 'defaults discovery to People but honors explicit categories and scoped links' do
    album = Album.create!(title: 'Album', artist: 'Music Group')
    get metadata_entities_path(library: 'all')
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#kind option[selected]')['value']).to eq('person')
    expect(doc.css('.entity-tile').text).to include('Olivia Wilde')
    expect(doc.css('.entity-tile').text).not_to include('Music Group')
    expect(doc.at_css('.entity-tile')['href']).to eq(metadata_entity_path(person, library: 'all'))
    get metadata_entities_path(kind: '', library: 'all', q: 'Music')
    expect(response.body).to include(album.metadata_entities.first.name)
    get metadata_entities_path(kind: 'artist', library: 'all')
    expect(response.body).to include('Music Group')
    expect(Nokogiri::HTML(response.body).css('.entity-tile').text).not_to include('Olivia Wilde')
  end

  it 'keeps explicit all-category, search and library choices across pages' do
    49.times do |index|
      Movie.create!(title: "Story #{index}", metadata_credits_data: [
                      { name: format('“Story %02d”', index), role: 'Collection', kind: 'collection' }
                    ])
    end
    get metadata_entities_path(kind: '', library: 'all', q: 'Story')
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('.entity-tile').size).to eq(30)
    expect(doc.css('.entity-tile strong').first.text).to eq('Story 00')
    next_page = doc.at_css('.pagination .next a')['href']
    get next_page
    doc = Nokogiri::HTML(response.body)
    expect(doc.css('.entity-tile strong').map(&:text)).to eq((30..48).map { |index| format('Story %02d', index) })
    expect(doc.at_css('#kind option[selected]')['value']).to eq('')
    expect(doc.at_css('#q')['value']).to eq('Story')
    expect(doc.at_css('.entity-tile')['href']).to include('library=all')
  end

  it 'sorts displayed storyline names before pagination without changing stored names' do
    names = ['Zulu', '“Atlantis Attacks”', '"Avengers" Acts of Vengeance', '"Exiles" A Blink in Time',
             'Avengers Academy', 'An "Internal" Quote', "O'Brien's Story"]
    names.each do |name|
      Movie.create!(title: name, metadata_credits_data: [{ name: name, role: 'Collection', kind: 'collection' }])
    end
    get metadata_entities_path(kind: 'collection', library: 'all')
    displayed = Nokogiri::HTML(response.body).css('.entity-tile strong').map(&:text)
    expect(displayed).to eq(['An "Internal" Quote', 'Atlantis Attacks', 'Avengers Academy', 'Avengers Acts of Vengeance',
                             'Exiles A Blink in Time', "O'Brien's Story", 'Zulu'])
    entity = MetadataEntity.find_by!(name: '“Atlantis Attacks”')
    get metadata_entity_path(entity, library: 'all')
    expect(Nokogiri::HTML(response.body).at_css('h1').text).to eq('Atlantis Attacks')
    expect(Nokogiri::HTML(response.body).at_css('.entity-monogram').text).to eq('A')
    expect(entity.reload.name).to eq('“Atlantis Attacks”')
    expect(entity.normalized_name).to eq('“atlantis attacks”')
    get metadata_entities_path(kind: 'collection', library: 'all', q: 'Avengers Acts')
    expect(Nokogiri::HTML(response.body).css('.entity-tile strong').map(&:text)).to eq(['Avengers Acts of Vengeance'])
  end
end
