# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeriesNavigationHelper do
  it 'links only absolute HTTP(S) sources without credentials' do
    expect(helper.source_link_or_text('https://example.com/item?q=1')).to include('<a ', 'rel="noopener noreferrer"')
    ['javascript:alert(1)', '//example.com', 'https://secret@example.com/path', 'not a URL'].each do |value|
      expect(helper.source_link_or_text(value)).to eq(value)
    end
  end

  it 'normalizes legacy string dates and treats malformed or missing values as unknown' do
    episode = TvEpisode.new(air_date: '2026-10-24')
    expect(helper.media_release_date(episode)).to eq(Date.new(2026, 10, 24))
    ['', nil, 'TBA', '2026-02-30'].each do |value|
      episode.air_date = value
      expect(helper.media_release_date(episode)).to be_nil
    end
  end
end
