# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivitiesHelper, type: :helper do
  let(:user) do
    User.create!(name: 'Alice', email: 'alice@example.com', password: 'password123', confirmed_at: Time.current)
  end

  describe '#activity_link_description' do
    it 'escapes HTML inside rating string' do
      movie = Movie.create!(title: 'Inception')
      lib_item = LibraryItem.create!(user: user, item: movie, rating: '5 <script>alert(1)</script>')
      activity = Activity.create!(user: user, trackable: lib_item, activity_type: 'reviewed')

      result = helper.activity_link_description(activity)

      expect(result).not_to include('<script>')
      expect(result).to include('5 &lt;script&gt;alert(1)&lt;/script&gt;')
    end

    it 'escapes HTML inside artist name in added activity' do
      album = Album.create!(title: 'Test Album', artist: '<b onmouseover=alert(1)>Evil Artist</b>')
      lib_item = LibraryItem.create!(user: user, item: album)
      activity = Activity.create!(user: user, trackable: lib_item, activity_type: 'added')

      result = helper.activity_link_description(activity)

      expect(result).not_to include('<b onmouseover')
      expect(result).to include('&lt;b onmouseover=alert(1)&gt;Evil Artist&lt;/b&gt;')
    end

    it 'escapes HTML inside artist name in reviewed activity' do
      album = Album.create!(title: 'Test Album', artist: '<script>alert("artist")</script>')
      lib_item = LibraryItem.create!(user: user, item: album)
      activity = Activity.create!(user: user, trackable: lib_item, activity_type: 'reviewed')

      result = helper.activity_link_description(activity)

      expect(result).not_to include('<script>')
      expect(result).to include('&lt;script&gt;alert(&quot;artist&quot;)&lt;/script&gt;')
    end
  end
end
