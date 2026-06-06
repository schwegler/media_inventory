# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'collections/show.html.erb', type: :view do
  let(:user) do
    User.create!(name: 'Charlie', email: 'charlie@example.com', password: 'password123',
                 password_confirmation: 'password123')
  end

  context 'when user is unconfirmed' do
    before do
      user.update!(confirmed_at: nil)
      assign(:user, user)
      render
    end

    it 'displays an alert that the collection is not public' do
      expect(rendered).to match(/This user's collection is not public/)
    end
  end

  context 'when user is confirmed' do
    let(:movie) { Movie.create!(title: 'The Matrix', director: 'Lana Wachowski', rating: 5, user: user) }
    let(:album) { Album.create!(title: 'Homework', artist: 'Daft Punk', rating: 5, user: user) }

    before do
      user.update!(confirmed_at: Time.current)
      assign(:user, user)
      assign(:albums, [album])
      assign(:comics, [])
      assign(:movies, [movie])
      assign(:tv_shows, [])
      assign(:wrestling_events, [])
      render
    end

    it 'renders the media items in the collection' do
      expect(rendered).to match(/The Matrix/)
      expect(rendered).to match(/Homework/)
      expect(rendered).not_to match(/This user's collection is not public/)
    end
  end
end
