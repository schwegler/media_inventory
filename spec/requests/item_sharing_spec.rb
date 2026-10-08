# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public item sharing', type: :request do
  def metadata
    document = Nokogiri::HTML(response.body)
    %w[title description image url].to_h do |name|
      [name, document.at_css("meta[property='og:#{name}']")['content']]
    end
  end

  [Movie, Album, Book, Comic, TvShow, VideoGame].each do |model|
    it "renders stable public metadata and a numeric canonical URL for #{model.name}" do
      item = model.create!(title: "Public #{model.name}", thumbnail_url: 'https://covers.example.org/public.png')
      item.cover_image.attach(io: File.open(Rails.root.join('public/favicon.svg')), filename: 'cover.svg',
                              content_type: 'image/svg+xml')
      get polymorphic_path(item), params: { ref: 'blog', review: 'DO NOT PUBLISH THIS NOTE' }

      expect(response).to have_http_status(:ok)
      expect(metadata['title']).to eq("Public #{model.name} | Trove")
      expect(metadata['description']).to be_present
      expect(metadata['image']).to start_with('https://trove.schweg.xyz/media/covers/')
      expect(response.body).not_to include('https://covers.example.org/public.png')
      expect(metadata['url']).to eq("https://trove.schweg.xyz/#{item.model_name.route_key}/#{item.id}")
      expect(metadata.values.join).not_to include('DO NOT PUBLISH THIS NOTE')
      document = Nokogiri::HTML(response.body)
      expect(document.at_css('link[rel="canonical"]')['href']).to eq(metadata['url'])
      expect(document.at_css('[data-link-share-url-value]')['data-link-share-url-value']).to eq(metadata['url'])
      expect(document.at_css('.blog-nav-link').text).to eq('Blog')
      expect(document.at_css('.blog-nav-link')['href']).to eq('https://tacobout.online/')
    end
  end

  it 'keeps an owner’s private collection review out of anonymous and authenticated metadata' do
    user = User.create!(name: 'Owner', email: 'owner@example.com', password: 'password123', confirmed_at: Time.current)
    movie = Movie.create!(title: 'Public movie', director: 'Public director', release_year: 2024)
    LibraryItem.create!(user: user, item: movie, is_public: false, review: 'PRIVATE COLLECTION NOTE')
    get movie_path(movie)
    guest_metadata = metadata
    expect(response.body).not_to include('PRIVATE COLLECTION NOTE')

    post login_path, params: { session: { email: user.email, password: 'password123' } }
    get movie_path(movie)
    expect(metadata).to eq(guest_metadata)
    expect(metadata.values.join).not_to include('PRIVATE COLLECTION NOTE')
  end

  it 'renders an absolute HTTPS image URL for an uploaded public cover' do
    movie = Movie.create!(title: 'Uploaded cover')
    movie.cover_image.attach(io: File.open(Rails.root.join('public/favicon.svg')), filename: 'cover.svg',
                             content_type: 'image/svg+xml')
    get movie_path(movie)
    expect(metadata['image']).to start_with('https://trove.schweg.xyz/media/covers/')
  end

  it 'uses an HTTPS fallback for an insecure thumbnail' do
    movie = Movie.create!(title: 'No secure cover', thumbnail_url: 'http://covers.example.org/cover.png')
    get movie_path(movie)
    expect(metadata['image']).to eq("https://trove.schweg.xyz/media/covers/movie/#{movie.id}")
  end

  it 'renders episode and issue catalog metadata without collection notes' do
    show = TvShow.create!(title: 'Public show')
    episode = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
    comic = Comic.create!(title: 'Public comic')
    issue = comic.comic_issues.create!(title: 'Public issue', issue_number: '1')
    [episode, issue].each do |item|
      get polymorphic_path(item)
      expect(response).to have_http_status(:ok)
      expect(metadata['title']).not_to eq('Trove')
      expect(metadata['description']).to include(item.is_a?(TvEpisode) ? show.title : comic.title)
      expect(metadata['url']).to eq("https://trove.schweg.xyz/#{item.model_name.route_key}/#{item.id}")
      expect(metadata['image']).to start_with('https://')
    end
  end
  it 'offers encoded social compose links and a native share button' do
    movie = Movie.create!(title: 'A & B #1')
    get movie_path(movie)
    document = Nokogiri::HTML(response.body)
    link = document.at_css('a[href^="https://bsky.app/intent/compose"]')
    text = URI.decode_www_form(URI(link['href']).query).to_h.fetch('text')
    expect(text).to eq("A & B #1 https://trove.schweg.xyz/movies/#{movie.id}")
    expect(link['rel']).to include('noopener')
    expect(document.at_css('[data-action="link-share#share"]')).to be_present
  end
end
