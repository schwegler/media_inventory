# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title public shelf discovery', type: :request do
  def publish_preview(user)
    user.shelf_previews.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                               filename: 'preview.png', content_type: 'image/png')
  end

  it 'uses published selections equally for visitors and owners without library state' do
    owner = User.create!(name: 'Published curator', username: 'published_curator', email: 'curator@example.com',
                         password: 'password123', confirmed_at: Time.current)
    movie = Movie.create!(title: 'Discovery fixture')
    owner.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    owner.shelf_collections.create!(title: 'Direct link collection', picks: [{ type: 'Movie', id: movie.id }])
    LibraryItem.create!(user: owner, item: movie, is_public: false, review: 'Private review sentinel', rating: 5)
    get movie_path(movie)
    expect(Nokogiri::HTML(response.body).at_css('.media-public-shelves')).to be_nil
    publish_preview(owner)
    get movie_path(movie)
    visitor = Nokogiri::HTML(response.body).at_css('.media-public-shelves')
    expect(visitor.text).to include('On public shelves', 'Published curator', '1 title')
    expect(visitor.text).not_to include('Private review sentinel', 'Direct link collection', 'Popular', 'rating')
    url = visitor.at_css('a')['href']
    get url
    expect(response).to have_http_status(:ok)
    post login_path, params: { session: { email: owner.email, password: 'password123' } }
    get movie_path(movie)
    owner_view = Nokogiri::HTML(response.body).at_css('.media-public-shelves')
    expect(owner_view.to_html).to eq(visitor.to_html)
    owner.update!(confirmed_at: nil)
    get movie_path(movie)
    expect(Nokogiri::HTML(response.body).at_css('.media-public-shelves')).to be_nil
  end

  it 'resolves previews in batches with bounded rows and no per-shelf query growth' do
    movie = Movie.create!(title: 'Bounded discovery fixture')
    7.times do |index|
      owner = User.create!(name: "Curator #{index}", username: "curator_#{index}", email: "curator#{index}@example.com",
                           password: 'password123', confirmed_at: Time.current)
      publish_preview(owner)
      owner.favorite_shelves.create!(category: 'Movie', picks: [{ type: 'Movie', id: movie.id }])
    end
    queries = []
    results = nil
    callback = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      ActiveRecord::Base.uncached { results = PublicShelfMembership.call(movie) }
    end
    expect(results.size).to eq(6)
    expect(results.flat_map { |row| row[:covers] }.size).to eq(6)
    expect(queries.size).to be <= 7
    expect(queries.grep(/library_items|shelf_collections/)).to be_empty
    expect(queries.first).to include('LIMIT')
  end
end
