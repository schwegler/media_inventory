# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::Overview do
  it 'counts blank strings, attached artwork, metadata IDs, and missing child records accurately' do
    Movie.create!(title: 'No artwork', thumbnail_url: '   ')
    illustrated = Movie.create!(title: 'Uploaded cover')
    illustrated.cover_image.attach(io: StringIO.new('image'), filename: 'cover.png', content_type: 'image/png')
    Movie.create!(title: 'Remote cover', thumbnail_url: 'https://example.com/art.jpg').update_columns(api_id: '42')
    show = TvShow.create!(title: 'Empty show')
    Comic.create!(title: 'Empty comic')
    snapshot = described_class.new.snapshot
    movies = snapshot[:catalog].find { |row| row['type'] == 'Movie' }
    expect(movies).to include('total' => 3, 'missing_artwork' => 1, 'missing_id' => 2)
    expect(snapshot[:catalog].find { |row| row['type'] == 'TvShow' }['without_children']).to eq(1)
    TvEpisode.create!(tv_show: show, name: 'Pilot')
    expect(Admin::Catalog.without_children(TvShow)).not_to include(show)
  end

  it 'caches only aggregate snapshot data and uses one union query for catalog coverage' do
    cache = ActiveSupport::Cache::MemoryStore.new
    allow(Rails).to receive(:cache).and_return(cache)
    statements = []
    listener = ->(_name, _start, _finish, _id, payload) { statements << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(listener, 'sql.active_record') { described_class.new.snapshot }
    expect(statements.count { |sql| sql.include?(' UNION ALL ') }).to eq(1)
    statements.clear
    ActiveSupport::Notifications.subscribed(listener, 'sql.active_record') { described_class.new.snapshot }
    expect(statements).to be_empty
  end

  it 'reports configuration state honestly without exposing tokens' do
    ApiConfiguration.create!(source_name: 'TMDB', media_type: 'Movie', is_active: true, base_url: 'https://example.com')
    ApiConfiguration.create!(source_name: 'RAWG', media_type: 'VideoGame', is_active: false, access_token: 'private')
    expect(described_class.new.integrations).to include(hash_including(name: 'TMDB', state: 'Credential needed'),
                                                        hash_including(name: 'RAWG', state: 'Disabled'))
    expect(described_class.new.integrations.to_s).not_to include('private', 'access_token')
    ApiConfiguration.create!(is_active: true)
    expect(described_class.new.integrations).to include(hash_including(state: 'Incomplete configuration'))
  end
end
