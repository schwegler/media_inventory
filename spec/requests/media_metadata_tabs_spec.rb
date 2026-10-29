# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Compact title metadata', type: :request do
  it 'renders linked screen credits once inside metadata and preserves the visible synopsis' do
    movie = Movie.create!(title: 'Metadata fixture', director: 'Director fixture', actors: 'Actor fixture',
                          genre: 'Drama', release_year: 2026,
                          metadata_details: { 'Overview' => 'The visible synopsis.', 'Runtime' => 90 })
    get movie_path(movie)
    doc = Nokogiri::HTML(response.body)
    metadata = doc.at_css('#title-details')
    expect(metadata.css('.media-metadata-panel').map { |panel| panel['id'] })
      .to eq(%w[metadata-details metadata-cast metadata-creators metadata-taxonomy])
    expect(metadata.css('#metadata-cast a').map(&:text)).to include('Actor fixture')
    expect(metadata.text.scan('Actor fixture').length).to eq(1)
    expect(metadata.text).not_to include('The visible synopsis.')
    expect(doc.at_css('#overview').text).to include('The visible synopsis.')
    expect(doc.css('.media-section-nav [role="tab"]')).to be_empty
    expect(metadata.css('[hidden]')).to all(satisfy { |node| node.name == 'button' })
  end

  it 'adapts categories to books, albums, comics, games and television without empty tabs' do
    items = [Book.create!(title: 'Book fixture', author: 'Author fixture'),
             Album.create!(title: 'Album fixture', artist: 'Artist fixture'),
             Comic.create!(title: 'Comic fixture', writer: 'Writer fixture'),
             VideoGame.create!(title: 'Game fixture', developer: 'Developer fixture',
                               metadata_details: { 'genres' => ['Action'], 'features' => ['Single-player'] }),
             TvShow.create!(title: 'TV fixture', actors: 'Actor fixture')]
    items.each do |item|
      get polymorphic_path(item)
      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML(response.body)
      expect(doc.css('#title-details .media-metadata-panel')).not_to be_empty
      expect(doc.css('#title-details').text).not_to include('Releases')
      expect(doc.css('#metadata-cast')).to be_empty unless item.is_a?(TvShow)
      expect(doc.css('.media-metadata-panel')).to all(satisfy { |node| node.css('dd').any? })
    end
  end

  it 'omits an empty metadata block and leaves series entries accessible' do
    show = TvShow.create!(title: 'Sparse show')
    show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
    get tv_show_path(show)
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('#title-details')).to be_nil
    expect(doc.at_css('#media-entries').text).to include('Pilot')
    expect(doc.at_css('#my-library')).not_to be_nil
  end
end
