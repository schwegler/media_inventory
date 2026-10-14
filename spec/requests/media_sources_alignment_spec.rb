# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Find This Title Links Alignment', type: :request do
  let!(:movie) { Movie.create!(title: 'Dune') }

  it 'renders structured icon, label, and external link layout for all rows' do
    get movie_path(movie)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="media-source-icon"')
    expect(response.body).to include('class="media-source-label"')
    expect(response.body).to include('Find this title')
  end

  [Movie, TvShow, Book, Album, Comic, VideoGame].each do |model|
    it "renders an official source for #{model.name} without crashing" do
      source_url = 'https://example.com/catalog/title'
      item = model.create!(title: 'Official source', external_url: source_url)

      get polymorphic_path(item)

      expect(response).to have_http_status(:ok)
      link = Nokogiri::HTML(response.body).at_css('.btn-stream-source')
      expect(link['href']).to eq(source_url)
      expect(link.text.strip).to eq('View Official Source')
      expect(link.at_css('.ui-icon--globe')).to be_present
      expect(link['target']).to eq('_blank')
      expect(link['rel']).to include('noopener')
    end
  end

  [
    [Album, 'https://music.apple.com/us/album/123', 'View on Apple Music', 'disc'],
    [Book, 'https://itunes.apple.com/us/book/123', 'View on Apple Books', 'book'],
    [Movie, 'https://tv.apple.com/us/movie/123', 'View on Apple TV', 'film'],
    [Book, 'https://openlibrary.org/books/OL123M', 'Borrow on Open Library', 'book'],
    [TvShow, 'https://www.tvmaze.com/shows/123', 'View on TVmaze', 'tv'],
    [VideoGame, 'https://store.steampowered.com/app/123', 'View on Steam', 'gamepad']
  ].each do |model, url, label, icon|
    it "renders the #{label} destination with its matching icon" do
      item = model.create!(title: 'Source destination', external_url: url)

      get polymorphic_path(item)

      expect(response).to have_http_status(:ok)
      link = Nokogiri::HTML(response.body).at_css('.btn-stream-source')
      expect(link['href']).to eq(url)
      expect(link.text.strip).to eq(label)
      expect(link.at_css(".ui-icon--#{icon}")).to be_present
    end
  end

  it 'identifies a source by its host instead of unrelated text in its query string' do
    item = Book.create!(title: 'Unrecognized source', external_url: 'https://example.com/?ref=music.apple.com')

    get book_path(item)

    link = Nokogiri::HTML(response.body).at_css('.btn-stream-source')
    expect(link.text.strip).to eq('View Official Source')
    expect(link.at_css('.ui-icon--globe')).to be_present
  end
end
