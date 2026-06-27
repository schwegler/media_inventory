# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivitiesHelper, type: :helper do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com', password: 'password', username: 'testuser') }
  let(:movie) { Movie.create!(title: 'Inception') }
  let(:malicious_rating) { '<script>alert("XSS")</script>' }
  let(:library_item) do
    LibraryItem.create!(
      user: user,
      item: movie,
      rating: malicious_rating,
      is_public: true
    )
  end
  let(:activity) do
    Activity.create!(
      user: user,
      trackable: library_item,
      activity_type: 'reviewed'
    )
  end

  describe '#activity_link_description' do
    it 'escapes malicious ratings' do
      description = helper.activity_link_description(activity)
      expect(description).not_to include(malicious_rating)
      expect(description).to include(CGI.escapeHTML(malicious_rating))
    end
  end
end
