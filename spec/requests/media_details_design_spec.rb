# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media title details', type: :request do
  it 'preserves each catalog’s metadata in the shared details section' do
    {
      Movie => { director: 'Director name', writer: 'Writer name', actors: 'Actor one, Actor two', genre: 'Adventure' },
      TvShow => { network: 'Network name', actors: 'Actor name' },
      Book => { author: 'Author name', publisher: 'Publisher name' },
      Album => { artist: 'Artist name', genre: 'Jazz' },
      Comic => { writer: 'Writer name', artist: 'Artist name', publisher: 'Publisher name' },
      VideoGame => { developer: 'Developer name', platform: 'PC' }
    }.each do |klass, attributes|
      item = klass.create!(attributes.merge(title: "Example #{klass.name}"))
      get polymorphic_path(item)
      follow_redirect! if response.redirect?
      expect(response).to have_http_status(:ok)
      document = Nokogiri::HTML(response.body)
      details = document.at_css('#title-details')
      attributes.each_value { |value| expect(details.text).to include(value) }
      expect(document.at_css('a[href="#title-details"]')).to be_present
    end
  end

  it 'groups game features and keeps audio notes separate from the language list' do
    item = VideoGame.create!(title: 'Detailed game', synopsis: 'A readable synopsis.', metadata_details: {
                               genres: %w[Action Adventure], features: ['Single-player', 'Steam Cloud'],
                               languages: 'English*, French*<br>*languages with full audio support',
                               controller_support: 'full'
                             })
    get polymorphic_path(item)
    follow_redirect! if response.redirect?
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('.game-description .child-description-prose').text).to include('A readable synopsis.')
    labels = document.css('.media-description-tags li').map { |tag| tag.text.strip }
    expect(labels).to eq(['Action', 'Adventure', 'Single-player', 'Steam Cloud'])
    expect(document.at_css('.media-description-disclosure p').text).to eq('English*, French*')
    expect(document.at_css('.media-description-disclosure small').text).to eq('* Full audio support')
    expect(document.at_css('#title-details').text).to include('Full')
  end

  it 'omits an empty details section and its navigation link' do
    item = Book.create!(title: 'Title only')
    get polymorphic_path(item)
    follow_redirect! if response.redirect?
    document = Nokogiri::HTML(response.body)
    expect(document.at_css('#title-details')).to be_nil
    expect(document.at_css('a[href="#title-details"]')).to be_nil
  end

  it 'promotes imported prose once, preserves distinct provider text, and sanitizes formatting' do
    item = Book.create!(title: 'A story', metadata_details: {
                          'Overview' => '<p>A <strong onclick="bad()">story</strong>.</p>',
                          'description' => 'A different edition note.', 'isbn_13' => '1234567890123'
                        })
    get book_path(item)
    document = Nokogiri::HTML(response.body)
    expect(document.css('.media-synopsis').size).to eq(1)
    expect(document.at_css('.media-synopsis strong').text).to eq('story')
    expect(document.css('.media-synopsis [onclick]')).to be_empty
    expect(document.css('.media-description-row dt').map(&:text)).not_to include('Synopsis')
    expect(document.at_css('#metadata-details').text).to include('A different edition note.',
                                                                 '1234567890123')
  end
end
