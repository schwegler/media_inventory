# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_media_actions_and_stream.html.erb', type: :view do
  let(:user) do
    User.create!(name: 'Test User', email: 'test@example.com', password: 'password', confirmed_at: Time.current)
  end
  let(:movie) { Movie.create!(title: 'Inception', release_year: 2010, is_collected: true) }

  before do
    allow(view).to receive(:logged_in?).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
    assign(:library_item, LibraryItem.create!(user: user, item: movie))
  end

  it 'renders quick review form fields with accessible aria-label attributes' do
    render partial: 'shared/media_actions_and_stream', locals: { item: movie }

    expect(rendered).to have_css('select[aria-label="Rating"]')
    expect(rendered).to have_css('textarea[aria-label="Add watch review..."]')
    expect(rendered).to have_css('select[aria-label="Physical format"]')
    expect(rendered).to have_css('select[aria-label="Digital format"]')
  end
end
