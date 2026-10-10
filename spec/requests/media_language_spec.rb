# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media-specific activity language', type: :request do
  let(:user) do
    User.create!(name: 'Reader', email: 'language@example.com', password: 'password123', confirmed_at: Time.current)
  end

  before { post login_path, params: { session: { email: user.email, password: 'password123' } } }

  it 'describes books and comic issues as read in both activity feeds and plain text' do
    book = Book.create!(title: 'A good book')
    issue = Comic.create!(title: 'A comic series').comic_issues.create!(title: 'First issue', issue_number: 1)
    [book, issue].each do |item|
      entry = LibraryItem.create!(user: user, item: item, consumed: true, is_public: true)
      activity = entry.activities.find_by!(activity_type: 'consumed')
      expect(activity.description).to start_with('Reader read ')
      expect(activity.display_type).to eq('read')
    end

    delete logout_path
    get root_path
    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    expect(document.css('.badge-consumed').map { |badge| badge.text.strip }).to eq(%w[read read])
    expect(document.css('.activity-text').map(&:text).join).not_to include('consumed')
  end

  it 'keeps album status updates working with natural listening labels' do
    album = Album.create!(title: 'A good album')
    entry = LibraryItem.create!(user: user, item: album)
    get album_path(album)
    expect(Nokogiri::HTML(response.body).css('#my-library button').map { |button| button.text.strip })
      .to include('Listened to')

    patch album_path(album), params: { album: { consumed: true } }
    follow_redirect!
    expect(entry.reload).to be_consumed
    expect(Nokogiri::HTML(response.body).css('#my-library button').map { |button| button.text.strip })
      .to include('✓ Listened to')
    expect(entry.activities.find_by!(activity_type: 'consumed').description).to include('listened to album')
  end

  it 'uses reading-list and read labels in the shared edit form' do
    book = Book.create!(title: 'A book to edit')
    LibraryItem.create!(user: user, item: book)
    get edit_book_path(book)
    labels = Nokogiri::HTML(response.body).css('label').map(&:text)
    expect(labels).to include('Read', 'In reading list')
    expect(labels).not_to include('Consumed', 'In watchlist')
  end
end
