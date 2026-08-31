# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_media_card.html.erb', type: :view do
  let(:movie) { Movie.create!(title: 'Inception', release_year: 2010) }

  it 'renders thumbnail image with descriptive alt text when thumbnail_url is present' do
    movie.update!(thumbnail_url: 'https://example.com/inception.jpg')

    render partial: 'shared/media_card', locals: { media_item: movie }

    expect(rendered).to have_css('img[alt="Inception cover"]')
    expect(rendered).to have_css('img[src="https://example.com/inception.jpg"]')
  end
end
