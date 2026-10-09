# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Readable public URLs', type: :request do
  [Movie, Book, Album, Comic, TvShow, VideoGame, ComicIssue, TvEpisode].each do |model|
    it "redirects old and stale #{model.name} URLs to one readable canonical URL" do
      item = case model.name
             when 'ComicIssue'
               Comic.create!(title: 'Uncanny X-Men (2024)').comic_issues.create!(issue_number: 1, title: 'Red Wave')
             when 'TvEpisode'
               TvShow.create!(title: '30 Rock').tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
             else
               model.create!(title: 'Dungeon Crawler Carl')
             end
      base = "/#{item.model_name.route_key}/#{item.id}"
      [base, "#{base}-old-title"].each do |legacy|
        get legacy, params: { ref: 'blog', q: 'a & b' }
        expect(response).to have_http_status(:moved_permanently)
        destination = URI(response.location)
        expect(destination.path).to eq(polymorphic_path(item))
        expect(URI.decode_www_form(destination.query).to_h).to include('ref' => 'blog', 'q' => 'a & b')
        follow_redirect!
        expect(response).to have_http_status(:ok)
        document = Nokogiri::HTML(response.body)
        expect(document.at_css('link[rel="canonical"]')['href']).to eq("https://trove.schweg.xyz#{polymorphic_path(item)}")
      end
    end
  end

  it 'keeps links working after a title change and distinguishes duplicate titles' do
    first = Book.create!(title: 'Original Title')
    old_path = book_path(first)
    first.update!(title: 'New Title')
    duplicate = Book.create!(title: 'New Title')
    expect(book_path(first)).not_to eq(book_path(duplicate))

    get old_path
    expect(response).to redirect_to(book_path(first))
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it 'serves symbol-only titles without redirect loops and unknown IDs as not found' do
    book = Book.create!(title: '!!!')
    get book_path(book)
    expect(response).to have_http_status(:ok)
    get '/books/999999999-missing-book'
    expect(response).to have_http_status(:not_found)
  end

  it 'uses usernames for collections and redirects numeric profile and collection links' do
    user = User.create!(name: 'Reader', username: 'reader', password: 'password123', confirmed_at: Time.current)
    [["/users/#{user.id}", user_path(user)], ["/collections/#{user.id}", collection_path(user)]].each do |legacy, path|
      get legacy
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(Nokogiri::HTML(response.body).at_css('link[rel="canonical"]')['href']).to eq("https://trove.schweg.xyz#{path}")
    end
  end

  it 'accepts readable URLs for updates and nested edit suggestions' do
    user = User.create!(name: 'Reader', email: 'readable@example.com', password: 'password123', confirmed_at: Time.current)
    book = Book.create!(title: 'Dungeon Crawler Carl')
    post login_path, params: { session: { email: user.email, password: 'password123' } }

    patch book_path(book), params: { book: { review: 'A good read', is_public: true } }
    expect(response).to redirect_to(book_path(book))
    expect(LibraryItem.find_by!(user: user, item: book).review).to eq('A good read')

    post book_edit_suggestions_path(book), params: { edit_suggestion: { proposed_changes: { title: 'A corrected title' } } }
    expect(response).to redirect_to(book_path(book))
    expect(book.edit_suggestions.last.proposed_changes).to eq('title' => 'A corrected title')
  end
end
