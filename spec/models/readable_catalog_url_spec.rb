# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReadableCatalogUrl do
  it 'generates readable title and year URLs across the main catalog types' do
    [Movie, Book, Album, VideoGame, Comic, TvShow].each do |model|
      item = model.new(id: 14, title: 'Café & The World!')
      item.release_year = 2024 if item.respond_to?(:release_year=)
      suffix = item.respond_to?(:release_year) ? '-2024' : ''
      expect(item.to_param).to eq("14-cafe-the-world#{suffix}")
    end
  end

  it 'includes the series and issue number even when the issue has no title' do
    comic = Comic.new(title: 'Uncanny X-Men (2024)')
    issue = ComicIssue.new(id: 42, comic: comic, issue_number: 1)
    expect(issue.to_param).to eq('42-uncanny-x-men-2024-1')
  end

  it 'includes the show, season, episode, and episode name' do
    episode = TvEpisode.new(id: 42, tv_show: TvShow.new(title: '30 Rock'), season: 1, episode: 2, name: 'The Aftermath')
    expect(episode.to_param).to eq('42-30-rock-s1e2-the-aftermath')
  end

  it 'does not repeat years already present in a title' do
    expect(Book.new(id: 14, title: 'A Book (2024)', release_year: 2024).to_param).to eq('14-a-book-2024')
  end

  it 'supports unsaved and symbol-only titles without invalid or looping URLs' do
    expect(Book.new(title: 'New Book').to_param).to be_nil
    expect(Book.new(id: 14, title: '!!!').to_param).to eq('14')
  end
end
