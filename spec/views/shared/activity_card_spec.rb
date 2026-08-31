# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_activity_card.html.erb', type: :view do
  let(:user) do
    User.create!(
      name: 'Jane Doe',
      email: 'jane@example.com',
      password: 'password',
      password_confirmation: 'password'
    )
  end
  let(:movie) { Movie.create!(title: 'The Matrix', release_year: 1999) }
  let(:library_item) { LibraryItem.create!(user: user, item: movie, rating: 5.0) }
  let(:activity) { Activity.create!(user: user, trackable: library_item, activity_type: 'reviewed') }

  it 'renders thumbnail image with descriptive alt text when thumbnail_url is present' do
    movie.update!(thumbnail_url: 'https://example.com/matrix.jpg')

    render partial: 'shared/activity_card', locals: { media_item: movie, activity: activity, lib_item: library_item }

    expect(rendered).to have_css('img[alt="The Matrix cover"]')
    expect(rendered).to have_css('img[src="https://example.com/matrix.jpg"]')
  end
end
