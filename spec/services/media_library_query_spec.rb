# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaLibraryQuery do
  let(:user) { User.create!(name: 'Media Lover', email: 'medialover@example.com', password: 'password123') }

  describe '#statistics' do
    it 'returns accurate library counts in a single SQL query' do
      tv1 = TvShow.create!(title: 'Series 1')
      tv2 = TvShow.create!(title: 'Series 2')
      tv3 = TvShow.create!(title: 'Series 3')

      LibraryItem.create!(user: user, item: tv1, in_backlog: true, is_collected: true)
      LibraryItem.create!(user: user, item: tv2, consumed: true)
      lib3 = LibraryItem.create!(user: user, item: tv3)
      ConsumptionPass.create!(library_item: lib3, status: 'active', number: 1)

      query = described_class.new(TvShow, user: user, filters: {})

      queries = []
      subscriber = lambda do |*, payload|
        queries << payload[:sql] unless payload[:name] == 'SCHEMA'
      end

      stats = nil
      ActiveSupport::Notifications.subscribed(subscriber, 'sql.active_record') do
        stats = query.statistics
      end

      expect(queries.size).to eq(1)
      expect(stats).to eq(
        all: 3,
        backlog: 1,
        finished: 1,
        collection: 1,
        progress: 1
      )
    end
  end
end
