# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  let(:viewer) { User.create!(name: 'Viewer', password: 'password123') }
  let(:author) { User.create!(name: 'Author', password: 'password123') }
  let(:movie) { Movie.create!(title: 'Community') }

  def entry(user:, **attributes)
    LibraryItem.create!({ user: user, item: movie, review: 'A review', is_public: true }.merge(attributes))
  end

  def measured_stats
    queries = []
    instances = []
    sql = ->(*args) { queries << args.last[:sql] if args.last[:sql].match?(/SELECT.*FROM "likes"/m) }
    records = ->(*args) { instances << args.last[:class_name] }
    result = nil
    ActiveSupport::Notifications.subscribed(records, 'instantiation.active_record') do
      ActiveSupport::Notifications.subscribed(sql, 'sql.active_record') do
        result = helper.community_stats_for(movie)
        result[:reviews].each do |review|
          html = helper.render('likes/like_button', item: review, like_stats: result[:review_likes].fetch(review.id))
          expect(html).to include(%(aria-pressed="#{result[:review_likes][review.id][:liked]}"))
        end
      end
    end
    [result, queries, instances]
  end

  [false, true].each do |signed_in|
    it "batches review reactions without instantiating likes when signed_in=#{signed_in}" do
      allow(helper).to receive(:logged_in?).and_return(signed_in)
      allow(helper).to receive(:current_user).and_return(signed_in ? viewer : nil)
      public_review = entry(user: author)
      own_private = entry(user: viewer, is_public: false)
      hidden_review = entry(user: User.create!(name: 'Private', password: 'password123'), is_public: false)
      no_review = entry(user: User.create!(name: 'Watcher', password: 'password123'), review: nil)
      Like.create!(user: viewer, likeable: public_review)
      Like.create!(user: author, likeable: public_review)
      Like.create!(user: viewer, likeable: movie)
      Like.create!(user: viewer, likeable: no_review)
      Like.create!(user: viewer, likeable: hidden_review)

      result, queries, instances = measured_stats
      expect(result[:review_likes][public_review.id]).to eq(count: 2, liked: signed_in)
      expect(result[:review_likes].key?(own_private.id)).to eq(signed_in)
      expect(result[:review_likes][own_private.id]).to eq(count: 0, liked: false) if signed_in
      expect(result[:review_likes].keys).not_to include(hidden_review.id, no_review.id)
      expect(queries.size).to eq(signed_in ? 2 : 1)
      expect(instances).not_to include('Like')

      5.times do |index|
        user = User.create!(name: "Reviewer #{index}", password: 'password123')
        Like.create!(user: viewer, likeable: entry(user: user))
      end
      _, larger_queries, larger_instances = measured_stats
      expect(larger_queries.size).to eq(queries.size)
      expect(larger_instances).not_to include('Like')
      expect(viewer.likes).not_to be_loaded
    end
  end

  it 'does not query likes when there are no written reviews' do
    allow(helper).to receive(:logged_in?).and_return(false)
    entry(user: author, review: ' ')
    result, queries, = measured_stats
    expect(result[:review_likes]).to eq({})
    expect(queries).to be_empty
  end
end
