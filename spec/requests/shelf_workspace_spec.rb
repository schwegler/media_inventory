# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Owner shelf workspace', type: :request do
  let(:owner) do
    User.create!(name: 'Curator', username: 'workspace_owner', email: 'workspace@example.com', password: 'password')
  end
  let(:movie) { Movie.create!(title: 'A winter discovery') }
  let(:collection) { owner.shelf_collections.create!(title: 'Winter nights', picks: [{ type: 'Movie', id: movie.id }]) }

  def login(user = owner)
    post login_path, params: { session: { email: user.email, password: 'password' } }
  end

  def version
    ApplicationController.helpers.shelf_edit_version(owner, "collection:#{collection.slug}")
  end

  it 'requires authentication and scopes every editor and archive action to its owner' do
    get shelf_workspace_path
    expect(response).to redirect_to(login_path)
    patch archive_managed_shelf_path(collection.slug)
    expect(response).to redirect_to(login_path)
    patch restore_managed_shelf_path(collection.slug)
    expect(response).to redirect_to(login_path)
    other = User.create!(name: 'Other', username: 'other_curator', email: 'other@example.com', password: 'password')
    login(other)
    [edit_managed_shelf_path(collection.slug), managed_shelf_settings_path(collection.slug),
     confirm_archive_shelf_path(collection.slug)].each do |path|
      get path
      expect(response).to have_http_status(:not_found)
    end
    patch archive_managed_shelf_path(collection.slug), params: { confirmation: collection.title, shelf_version: version }
    expect(response).to have_http_status(:not_found)
    expect(collection.reload.archived_at).to be_nil
    collection.update_column(:archived_at, Time.current)
    patch restore_managed_shelf_path(collection.slug)
    expect(response).to have_http_status(:not_found)
    expect(collection.reload.archived_at).to be_present
  end

  it 'lists all seven favorites and custom shelves before public exhibitions' do
    collection
    login
    get my_shelf_path
    expect(response).to redirect_to(shelf_workspace_path)
    get shelf_workspace_path
    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('h1').text).to eq('Shelves')
    expect(doc.css('#favorites-heading ~ .workspace-row').size).to eq(7)
    expect(doc.at_css("a[href='#{new_managed_shelf_path}']")).to be_present
    expect(response.body).to include('Winter nights')
  end

  it 'retains invalid creation values and deduplicates a repeated successful submission' do
    login
    get new_managed_shelf_path
    token = Nokogiri::HTML(response.body).at_css('input[name="creation_token"]')['value']
    post managed_shelves_path, params: { creation_token: token, shelf_collection: { title: '', description: 'Keep this' } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include('Keep this', 'Check your shelf')
    input = { creation_token: token, starting_mood: 'halloween', shelf_collection: { title: 'Created once' } }
    expect { 2.times { post managed_shelves_path, params: input } }.to change(ShelfCollection, :count).by(1)
    created = owner.shelf_collections.find_by!(title: 'Created once')
    expect(response).to redirect_to(edit_managed_shelf_path(created.slug))
    expect(created.presentation['theme']).to eq('halloween')
    expect(created.picks).to eq([])
  end

  it 'keeps independently opened creation forms independent' do
    login
    tokens = 2.times.map do
      get new_managed_shelf_path
      Nokogiri::HTML(response.body).at_css('input[name="creation_token"]')['value']
    end
    expect(tokens.uniq.size).to eq(2)
    expect do
      tokens.each_with_index do |token, index|
        post managed_shelves_path, params: { creation_token: token,
                                             shelf_collection: { title: "Independent shelf #{index}" } }
        expect(response).to have_http_status(:see_other)
      end
    end.to change(ShelfCollection, :count).by(2)
    expect(owner.shelf_collections.pluck(:title)).to contain_exactly('Independent shelf 0', 'Independent shelf 1')
  end

  it 'moves editors off public views for owners as well as visitors' do
    login
    get shelf_path(owner.username, collection: collection.slug)
    doc = Nokogiri::HTML(response.body)
    expect(doc.at_css('.favorite-shelf')['data-favorite-shelf-owner-value']).to eq('false')
    expect(doc.css('.shelf-controls, .shelf-settings, .shelf-customization')).to be_empty
    expect(doc.at_css("a[href='#{edit_managed_shelf_path(collection.slug)}']")).to be_present
    get edit_managed_shelf_path(collection.slug)
    expect(response).to have_http_status(:ok)
    expect(Nokogiri::HTML(response.body).at_css('.favorite-shelf')['data-favorite-shelf-owner-value']).to eq('true')
  end

  it 'keeps data and slug while editing and rejects stale changes inline' do
    login
    previous = collection.attributes.slice('slug', 'picks', 'presentation')
    old_version = version
    patch update_managed_shelf_path(collection.slug), params: { shelf_version: old_version,
                                                                shelf_collection: { title: 'Renamed', preview_length: 1 } }
    expect(response).to redirect_to(edit_managed_shelf_path(collection.slug))
    expect(collection.reload.attributes.slice('slug', 'picks', 'presentation')).to eq(previous)
    patch update_managed_shelf_path(collection.slug), params: { shelf_version: old_version,
                                                                shelf_collection: { title: 'Stale rename' } }
    expect(response).to have_http_status(:conflict)
    expect(collection.reload.title).to eq('Renamed')
  end

  it 'requires confirmation and restores original URLs, selections and order without hard deletion' do
    login
    library_item = owner.library_items.create!(item: movie, review: 'Private library note', is_public: false)
    library_before = library_item.attributes
    original = collection.attributes.except('archived_at')
    patch archive_managed_shelf_path(collection.slug), params: { shelf_version: version, confirmation: 'wrong' }
    expect(response).to have_http_status(:unprocessable_content)
    expect(collection.reload.archived_at).to be_nil
    patch archive_managed_shelf_path(collection.slug), params: { shelf_version: version, confirmation: collection.title }
    expect(response).to redirect_to(shelf_workspace_path)
    expect(collection.reload.archived_at).to be_present
    get shelf_path(owner.username, collection: collection.slug)
    expect(response).to have_http_status(:not_found)
    get shelf_path(owner.username)
    expect(response.body).not_to include(collection.title)
    get shelf_workspace_path
    expect(response.body).to include('Archived shelves', 'Restore shelf')
    patch restore_managed_shelf_path(collection.slug)
    expect(response).to redirect_to(shelf_workspace_path)
    expect(collection.reload.attributes.except('archived_at')).to eq(original)
    expect(library_item.reload.attributes).to eq(library_before)
    expect(Movie.exists?(movie.id)).to be(true)
    get shelf_path(owner.username, collection: collection.slug)
    expect(response).to have_http_status(:ok)
  end
end
