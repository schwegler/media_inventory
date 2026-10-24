# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaLayoutHelper, type: :helper do
  before { helper.extend MetadataEntitiesHelper }

  it 'chooses readable canonical prose before imported descriptions' do
    game = VideoGame.new(synopsis: '<p>Canonical story</p>', metadata_details: { 'description' => 'Imported story' })
    expect(helper.media_synopsis(game)).to eq('<p>Canonical story</p>')
    game.synopsis = '<p> </p>'
    expect(helper.media_synopsis(game)).to eq('Imported story')
  end

  it 'falls back from an empty overview to a provider description and ignores invalid values' do
    book = Book.new(metadata_details: { 'Overview' => '<p> </p>', 'description' => '<p>A book story</p>' })
    expect(helper.media_synopsis(book)).to eq('<p>A book story</p>')
    book.metadata_details = { 'Overview' => ['Invalid'], 'description' => 12 }
    expect(helper.media_synopsis(book)).to be_nil
  end

  [
    [Movie, :director, 'Director'],
    [Movie, :writer, 'Writer'],
    [Movie, :actors, 'Actor'],
    [TvShow, :writer, 'Writer'],
    [Comic, :writer, 'Writer'],
    [Comic, :artist, 'Artist'],
    [Album, :artist, 'Album artist'],
    [Book, :author, 'Author']
  ].each do |model, attribute, role|
    it "links #{model} #{attribute} directly to its canonical entity" do
      item = model.create!(title: 'A title', attribute => 'Shared Name')
      entity = item.metadata_credits.find_by!(role: role).metadata_entity
      html = Nokogiri::HTML.fragment(helper.render_media_metadata_value(item, attribute, 'Shared Name'))

      expect(html.css('a').map { |link| link['href'] }).to eq([metadata_entity_path(entity)])
      expect(html.at_css('a').text).to eq('Shared Name')
    end
  end

  it 'preserves the supplied order when linking multiple actors' do
    movie = Movie.create!(title: 'An ensemble', actors: 'Zoe Actor, Amy Actor')
    html = Nokogiri::HTML.fragment(helper.render_media_metadata_value(movie, :actors, movie.actors))

    expect(html.css('a').map(&:text)).to eq(['Zoe Actor', 'Amy Actor'])
  end

  it 'keeps comic creator fallback links out of music categories before backfill' do
    comic = Comic.new(title: 'Legacy comic', artist: 'Legacy Artist')
    html = helper.render_media_metadata_value(comic, :artist, comic.artist)

    expect(html).to include('/categories/comic-creators/Legacy%20Artist')
    expect(html).not_to include('/categories/artists/')
  end

  it 'retains escaped plain values for fields without linked metadata' do
    expect(helper.render_media_metadata_value(Movie.new, :release_year, '<script>')).to eq('&lt;script&gt;')
  end
end
