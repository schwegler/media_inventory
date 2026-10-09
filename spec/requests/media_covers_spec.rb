# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Stored catalog cover recovery', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:source) { 'https://covers.openlibrary.org/b/id/123-M.jpg' }
  let(:png) do
    Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aO1sAAAAASUVORK5CYII=')
  end

  before do
    stub_request(:get, source).to_return(body: png, headers: { 'Content-Type' => 'image/png' })
  end

  def legacy_item(klass)
    item = klass.create!(title: 'Legacy artwork')
    item.update_columns(thumbnail_url: source)
    item
  end

  it 'recovers all six legacy categories on image access and serves the stored file thereafter' do
    [Movie, TvShow, Album, VideoGame, Comic, Book].each do |klass|
      item = legacy_item(klass)
      get polymorphic_path(item)
      expect(response.body).to include(item.stored_cover_url)
      expect(response.body).not_to include(source)
      expect(item.reload.cover_image).not_to be_attached
      get item.stored_cover_url
      expect(response).to have_http_status(:found)
      expect(response.location).to include('/rails/active_storage/')
      expect(item.reload.cover_image).to be_attached
      get item.stored_cover_url
      expect(response).to have_http_status(:found)
    end
    # Identical artwork is downloaded once across records, including repeat loads.
    expect(WebMock).to have_requested(:get, source).once
  end

  it 'keeps cached cover destinations usable after disk signatures would have expired' do
    item = legacy_item(Book)
    get item.stored_cover_url
    destination = URI(response.location).request_uri
    expect(destination).to include('/blobs/proxy/')
    travel 20.minutes do
      get destination
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('image/png')
      expect(response.body.b).to eq(png.b)
      expect(response).not_to be_redirect
    end
    expect(WebMock).to have_requested(:get, source).once
  end

  it 'preserves parent cover fallbacks for episodes and issues without their own artwork' do
    show = legacy_item(TvShow)
    episode = show.tv_episodes.create!(name: 'Pilot', season: 1, episode: 1)
    comic = legacy_item(Comic)
    issue = comic.comic_issues.create!(title: 'Issue', issue_number: 1)
    [[episode, show], [issue, comic]].each do |child, parent|
      get polymorphic_path(child)
      expect(response.body).to include(parent.stored_cover_url)
    end
  end

  it 'recovers imported files missing from disk without replacing the blob or manual uploads' do
    item = legacy_item(Book)
    get item.stored_cover_url
    blob = item.reload.cover_image.blob
    blob.service.delete(blob.key)
    get item.stored_cover_url
    expect(response).to have_http_status(:found)
    expect(item.reload.cover_image.blob.id).to eq(blob.id)
    expect(blob.service.exist?(blob.key)).to be(true)
    expect(WebMock).to have_requested(:get, source).twice
  end

  it 'recovers historical HTTP provider URLs over HTTPS without a browser hotlink' do
    item = legacy_item(Book)
    item.update_columns(thumbnail_url: source.sub('https:', 'http:'))
    get item.stored_cover_url
    expect(response).to have_http_status(:found)
    expect(item.reload.cover_image).to be_attached
    expect(WebMock).to have_requested(:get, source).once
    expect(WebMock).not_to have_requested(:get, source.sub('https:', 'http:'))
  end

  it 'serves existing manual uploads without contacting the source' do
    item = legacy_item(Book)
    item.cover_image.attach(io: StringIO.new(png), filename: 'manual.png', content_type: 'image/png')
    get item.stored_cover_url
    expect(response.location).to include('manual.png')
    expect(WebMock).not_to have_requested(:get, source)
  end

  it 'uses a local placeholder and a cooldown when an upstream image is unavailable' do
    item = legacy_item(Book)
    stub_request(:get, source).to_return(status: 404)
    2.times do
      get item.stored_cover_url
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('image/svg+xml')
      expect(response.headers['Cache-Control']).to eq('no-store')
    end
    expect(WebMock).to have_requested(:get, source).once
    expect(item.reload.cover_image).not_to be_attached
  end

  it 'rejects unsupported record types and never fetches a URL from request parameters' do
    get '/media/covers/user/1', params: { url: 'http://127.0.0.1/' }
    expect(response).to have_http_status(:not_found)
    expect(WebMock).not_to have_requested(:get, /127.0.0.1/)
  end
end
