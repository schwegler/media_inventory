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
    expect(rendered).to have_css('img[src*="/media/covers/"]')
    expect(rendered).not_to include('https://example.com/')
  end
  it 'keeps the director as the only movie credit while preserving the year and detail link' do
    movie.update!(director: 'Christopher Nolan', writer: 'Christopher Nolan, Jonathan Nolan', genre: 'Science Fiction')

    render partial: 'shared/media_card', locals: { media_item: movie }

    expect(rendered).to have_css('.card-2026-creator', text: 'Christopher Nolan')
    expect(rendered).to have_css('.card-2026-year', text: '2010')
    expect(rendered).to have_link('Inception', href: movie_path(movie))
    expect(rendered).not_to include('Jonathan Nolan', 'Science Fiction')
  end

  it 'does not render empty creator or rating rows for sparse metadata' do
    render partial: 'shared/media_card', locals: { media_item: movie }

    expect(rendered).not_to have_css('.card-2026-creator')
    expect(rendered).not_to have_css('.card-2026-ratings')
    expect(rendered).to have_link('Inception')
  end
end
