# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile library mix and avatar mascot badge', type: :request do
  let!(:user) do
    User.create!(
      name: 'Curator Alex',
      username: 'curator_alex',
      email: 'alex@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
  end

  let!(:movie) { Movie.create!(title: 'Favorite Film', release_year: 2024) }
  let!(:book) { Book.create!(title: 'Favorite Novel') }

  before do
    LibraryItem.create!(user: user, item: movie, is_collected: true, is_public: true)
    LibraryItem.create!(user: user, item: book, is_collected: true, is_public: true)
  end

  it 'renders Crate Digger Facet mascot badge in the profile header' do
    get handle_profile_path(user.username)
    expect(response).to have_http_status(:ok)
    page = Nokogiri::HTML(response.body)

    badge = page.at_css('.profile-heading-avatar-group .profile-facet-badge img')
    expect(badge).to be_present
    expect(badge['src']).to include('brand/facet_pose_03_crate_digger')
    expect(badge['class']).to include('mascot-sticker')
  end

  it 'renders visual horizontal progress bars for library mix with calculated widths' do
    get handle_profile_path(user.username)
    page = Nokogiri::HTML(response.body)

    mix_section = page.at_css('.profile-mix')
    expect(mix_section).to be_present
    bars = mix_section.css('.library-mix-bars .mix-row')
    expect(bars.size).to eq(ProfilesHelper::PROFILE_MEDIA_TYPES.size)

    # 1 movie and 1 book out of 2 total = 50% each
    movie_row = bars.find { |row| row.text.include?('Movies') }
    expect(movie_row).to be_present
    expect(movie_row.at_css('.mix-count').text.strip).to eq('1')
    expect(movie_row.at_css('.mix-bar-fill')['style']).to include('width: 50%;')

    book_row = bars.find { |row| row.text.include?('Books') }
    expect(book_row).to be_present
    expect(book_row.at_css('.mix-count').text.strip).to eq('1')
    expect(book_row.at_css('.mix-bar-fill')['style']).to include('width: 50%;')
  end

  it 'displays a friendly backlog incoming note for zero-logged video games' do
    get handle_profile_path(user.username)
    page = Nokogiri::HTML(response.body)

    game_row = page.css('.profile-mix .mix-row').find { |row| row.text.include?('Video Games') }
    expect(game_row).to be_present
    expect(game_row.at_css('.mix-zero-note').text).to include('0 logged yet · (backlog incoming)')
    expect(game_row.at_css('.mix-bar-fill')['style']).to include('width: 0%;')
  end
end
