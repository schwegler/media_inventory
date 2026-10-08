# frozen_string_literal: true

# Provider code runs identically in tests and production. Default external
# catalogs to empty responses; integration examples register specific fixtures.
RSpec.configure do |config|
  config.before do
    MediaSources::Registry::CACHE.clear
    %w[archive.org itunes.apple.com en.wikipedia.org openlibrary.org musicbrainz.org
       store.steampowered.com api.themoviedb.org api.rawg.io comicvine.gamespot.com].each do |host|
      stub_request(:get, %r{\Ahttps://#{Regexp.escape(host)}/}).to_return(body: '{}',
                                                                          headers: { 'Content-Type' => 'application/json' })
    end
    stub_request(:get, %r{\Ahttps://api.tvmaze.com/}).to_return(body: '[]',
                                                                headers: { 'Content-Type' => 'application/json' })
  end
end
