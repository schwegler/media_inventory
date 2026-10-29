# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewExcerptsHelper, type: :helper do
  it 'reuses supplied authors and media without adding per-excerpt queries' do
    author = User.create!(name: 'Reader', email: 'excerpt-query@example.com', password: 'password123')
    items = 6.times.map { |n| Movie.create!(title: "Movie #{n}") }
    ids = items.map do |item|
      LibraryItem.create!(user: author, item: item, is_public: true, review: 'Long review. ' * 100).id
    end
    entries = LibraryItem.where(id: ids).order(:id).to_a
    allow(helper).to receive(:current_user).and_return(nil)
    helper.review_summary(entries.first, item: items.first, author: author)
    queries = []
    subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, event|
      queries << event[:sql] if event[:sql].start_with?('SELECT') && !event[:cached]
    end
    begin
      entries.zip(items).each do |entry, item|
        expect(helper.review_summary(entry, item: item, author: author)).to include('Read full review')
      end
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
    expect(queries).to be_empty
  end
end
