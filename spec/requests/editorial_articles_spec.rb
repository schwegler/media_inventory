# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Cached editorial title cards', type: :request do
  let!(:movie) { Movie.create!(title: 'Reading fixture') }
  let!(:article) do
    EditorialArticle.create!(wordpress_id: 17, title: '<script>unsafe</script> A story', excerpt: '<img onerror=alert(1)>',
                             canonical_url: 'https://tacobout.online/story/', image_url: 'javascript:alert(1)',
                             published_at: Time.utc(2026, 10, 20),
                             source_modified_at: Time.current, checked_at: Time.current)
  end

  it 'renders safe cached cards outside reviews without any upstream fetch or rating changes' do
    article.editorial_article_titles.create!(item: movie)
    expect(Editorial::Client).not_to receive(:new)
    expect { get movie_path(movie) }.not_to change(LibraryItem, :count)
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    section = document.at_css('#from-tacobout')
    expect(section.at_css('h2').text).to eq('from taco ’bout it')
    expect(section.at_css('h3 a')['href']).to eq(article.canonical_url)
    expect(section.at_css('time')['datetime']).to start_with('2026-10-20')
    expect(section.css('script, img')).to be_empty
    expect(section.text).to include('<script>unsafe</script>')
    expect(section.ancestors.any? { |node| node['id'] == 'community' }).to be false
    expect(document.at_css('.media-overview-stats').text).to include('—')
  end

  it 'omits the section and navigation for unrelated or suppressed titles' do
    get movie_path(movie)
    expect(response.body).not_to include('id="from-tacobout"', 'href="#from-tacobout"', 'class="media-priority"')
    expect(Nokogiri::HTML(response.body).at_css('.media-detail-main #my-library')).to be_present
    article.editorial_article_titles.create!(item: movie)
    article.update!(published: false)
    get movie_path(movie)
    expect(response.body).not_to include('id="from-tacobout"')
  end

  it 'uses the shared section on every supported title and child route' do
    show = TvShow.create!(title: 'Show')
    comic = Comic.create!(title: 'Comic')
    items = [movie, Book.create!(title: 'Book'), Album.create!(title: 'Album'), VideoGame.create!(title: 'Game'),
             show, comic, show.tv_episodes.create!(name: 'Episode', season: 1, episode: 1),
             comic.comic_issues.create!(title: 'Issue', issue_number: '1')]
    items.each do |item|
      article.editorial_article_titles.create!(item: item)
      get polymorphic_path(item)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="from-tacobout"')
      document = Nokogiri::HTML(response.body)
      priority = document.at_css(%w[TvEpisode
                                    ComicIssue].include?(item.class.name) ? '.media-priority' : '.media-detail-main')
      expect(priority.at_css('#from-tacobout')).to be_present
      expect(document.css('#from-tacobout').size).to eq(1)
      expect(document.css('#my-library').size).to eq(1) unless %w[TvEpisode ComicIssue].include?(item.class.name)
      if %w[TvEpisode ComicIssue].include?(item.class.name)
        expect(priority.children.select(&:element?).first['id']).to eq("#{item.model_name.param_key}_tracking_#{item.id}")
      end
    end
  end
end
