# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_media_card.html.erb', type: :view do
  let(:movie) { Movie.create!(title: 'Inception', release_year: 2010) }

  it 'renders thumbnail image with descriptive alt text from app storage' do
    movie.update!(thumbnail_url: 'https://example.com/inception.jpg')
    movie.cover_image.attach(io: File.open(Rails.root.join('public/favicon.svg')), filename: 'cover.svg',
                             content_type: 'image/svg+xml')

    render partial: 'shared/media_card', locals: { media_item: movie }

    expect(rendered).to have_css('img[alt="Inception cover"]')
    expect(rendered).to have_css('img[src*="/rails/active_storage/"]')
    expect(rendered).not_to include('https://example.com/')
  end
end
