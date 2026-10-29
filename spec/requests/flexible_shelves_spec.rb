# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Flexible custom shelves', type: :request do
  let(:owner) do
    User.create!(name: 'Shelf Owner', username: 'flexible_owner', email: 'flexible@example.com', password: 'password')
  end
  let(:movies) { 8.times.map { |index| Movie.create!(title: "Discovery #{index}") } }
  let(:picks) { movies.map { |movie| { 'type' => 'Movie', 'id' => movie.id } } }
  let(:collection) { owner.shelf_collections.create!(title: 'A longer shelf', picks: picks) }

  def login(user = owner)
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  it 'keeps all custom titles while leaving the favorite limit unchanged' do
    expect(collection.items).to eq(movies)
    expect(collection.preview_items.size).to eq(5)
    expect(owner.favorite_shelves.new(category: 'overall', picks: picks)).not_to be_valid
    collection.update!(preview_length: 2)
    expect(collection.reload.picks.size).to eq(8)
    get shelf_path(owner.username, collection: collection.slug)
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)
    expect(page.css('.favorite-shelf-slots .shelf-slot').size).to eq(8)
    expect(page.css('.shelf-action-bar button').map(&:text)).to eq(['Copy link', 'Share'])
    get shelf_path(owner.username)
    previews = Nokogiri::HTML(response.body).css('.shelf-collection-covers img, .shelf-missing-cover')
    expect(previews.size).to eq(2)
    expect(response.body).to include('8 selections')
    expect(Nokogiri::HTML(response.body).at_css('h1').text.squish).to eq('The things I keep.')
  end

  it 'preserves selections, slug and presentation when restricting future additions' do
    login
    slug = collection.slug
    patch shelf_path(owner.username, collection: slug),
          params: { collection_details: { title: 'Renamed', preview_length: 1, allowed_media_types: ['', 'Book'] } }
    expect(response).to have_http_status(:see_other)
    expect(collection.reload.picks).to eq(picks)
    expect(collection.slug).to eq(slug)
    book = Book.create!(title: 'New book')
    patch shelf_path(owner.username, collection: slug), params: { picks: picks + [{ type: 'Book', id: book.id }] },
                                                        as: :json
    expect(response).to have_http_status(:ok)
    movie = Movie.create!(title: 'Not allowed as a new pick')
    patch shelf_path(owner.username, collection: slug), params: { picks: picks + [{ type: 'Movie', id: movie.id }] },
                                                        as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(collection.reload.picks.size).to eq(9)
  end

  it 'rejects stale editor writes without overwriting selections' do
    login
    version = ApplicationController.helpers.shelf_preview_signature(owner, "collection:#{collection.slug}")
    patch shelf_path(owner.username, collection: collection.slug),
          params: { picks: picks.reverse, shelf_version: version }, as: :json
    expect(response).to have_http_status(:ok)
    patch shelf_path(owner.username, collection: collection.slug), params: { picks: picks, shelf_version: version },
                                                                   as: :json
    expect(response).to have_http_status(:conflict)
    expect(collection.reload.picks).to eq(picks.reverse)
  end

  it 'rejects stale appearance saves from another editor' do
    login
    version = ApplicationController.helpers.shelf_preview_signature(owner, "collection:#{collection.slug}")
    patch shelf_path(owner.username, collection: collection.slug),
          params: { presentation: { theme: 'gallery' }, shelf_version: version }, as: :json
    expect(response).to have_http_status(:ok)
    patch shelf_path(owner.username, collection: collection.slug),
          params: { presentation: { theme: 'electric' }, shelf_version: version }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(collection.reload.presentation['theme']).to eq('gallery')
  end

  it 'protects overview appearance edits without invalidating existing favorite image signatures' do
    login
    signature = ApplicationController.helpers.shelf_preview_signature(owner, 'overview')
    version = ApplicationController.helpers.shelf_edit_version(owner, 'overview')
    patch shelf_path(owner.username), params: { presentation: { theme: 'gallery' }, shelf_version: version }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['shelf_version']).not_to eq(version)
    expect(ApplicationController.helpers.shelf_preview_signature(owner.reload, 'overview')).to eq(signature)
    patch shelf_path(owner.username), params: { presentation: { theme: 'electric' }, shelf_version: version }, as: :json
    expect(response).to have_http_status(:conflict)
  end

  it 'rejects visitor and anonymous mutations and leaks no private library fields' do
    collection
    visitor = User.create!(name: 'Visitor', email: 'shelfvisitor@example.com', password: 'password')
    login(visitor)
    patch shelf_path(owner.username, collection: collection.slug), params: { picks: [] }, as: :json
    expect(response).to have_http_status(:forbidden)
    get shelf_path(owner.username, collection: collection.slug)
    page = Nokogiri::HTML(response.body)
    expect(page.css('.shelf-settings, .shelf-customization')).to be_empty
    payload = JSON.parse(page.at_css('.favorite-shelf')['data-favorite-shelf-picks-value'])
    expect(payload.first.keys.sort).to eq(%w[cover id title type url])
    delete logout_path
    patch shelf_path(owner.username, collection: collection.slug), params: { picks: [] }, as: :json
    expect(response).to have_http_status(:redirect)
    expect(collection.reload.picks).to eq(picks)
  end

  it 'keeps a large shelf intact through repeated saves and shorter previews' do
    titles = 72.times.map { |index| Movie.create!(title: "Large shelf title #{index}") }
    large = owner.shelf_collections.create!(title: 'A year of discoveries',
                                            picks: titles.map { |title| { type: 'Movie', id: title.id } })
    login
    2.times do
      patch shelf_path(owner.username, collection: large.slug),
            params: { collection_details: { preview_length: 1 } }
      expect(response).to have_http_status(:see_other)
    end
    expect(large.reload.picks.size).to eq(72)
    get shelf_path(owner.username, collection: large.slug)
    expect(Nokogiri::HTML(response.body).css('.favorite-shelf-slots .shelf-slot').size).to eq(72)
  end

  it 'enforces operational capacity without truncating existing oversized records' do
    stub_const('ShelfCollection::MAX_PICKS', 5)
    original = picks.first(5)
    capped = owner.shelf_collections.create!(title: 'At capacity', picks: original)
    expect(capped.update(picks: picks.first(6))).to be(false)
    expect(capped.errors[:picks].join).to include('up to 5 titles')
    expect(capped.reload.picks).to eq(original)
    # Representative pre-existing oversized record: changing settings must preserve it.
    capped.update_columns(picks: picks)
    expect(capped.reload.operational_capacity).to eq(8)
    expect(capped.update(preview_length: 1)).to be(true)
    expect(capped.reload.picks).to eq(picks)
  end

  it 'rejects malformed identities, duplicates and unknown media types' do
    expect(owner.shelf_collections.new(title: 'Invalid', picks: [{ type: 'User', id: owner.id }])).not_to be_valid
    expect(owner.shelf_collections.new(title: 'Invalid', picks: [picks.first, picks.first])).not_to be_valid
    expect(owner.shelf_collections.new(title: 'Invalid', picks: [{ type: 'Movie', id: {} }])).not_to be_valid
    login
    patch shelf_path(owner.username, collection: collection.slug),
          params: { picks: [{ type: 'Movie', id: {} }] }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(collection.update(preview_length: 0)).to be(false)
    expect(collection.update(allowed_media_types: ['User'])).to be(false)
  end
end
