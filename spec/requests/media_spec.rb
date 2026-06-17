# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Media Autocomplete', type: :request do
  let!(:user) do
    User.create!(name: 'Tester', email: 'tester@example.com', password: 'password123',
                 password_confirmation: 'password123')
  end

  before do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  describe 'GET /media/autocomplete' do
    context 'when query is blank' do
      it 'returns an empty array' do
        get '/media/autocomplete', params: { q: '', type: 'movie' }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end

    context 'with movies' do
      let!(:movie1) { Movie.create!(title: 'Star Wars', director: 'George Lucas', release_year: 1977, user: user) }
      let!(:movie2) { Movie.create!(title: 'Star Trek', director: 'Gene Roddenberry', release_year: 1979, user: user) }

      it 'returns matching movies' do
        get '/media/autocomplete', params: { q: 'star', type: 'movie' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(2)
        expect(json.map { |j| j['title'] }).to contain_exactly('Star Wars', 'Star Trek')
        expect(json.first['is_local']).to be(true)
      end

      it 'supports case-insensitive searches' do
        get '/media/autocomplete', params: { q: 'WARS', type: 'movie' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['title']).to eq('Star Wars')
      end

      it 'returns the active storage attachment URL if cover_image is attached' do
        # Create temp file and attach it
        temp_file = Tempfile.new(['cover', '.png'])
        temp_file.write('dummy content')
        temp_file.rewind

        movie1.cover_image.attach(io: temp_file, filename: 'cover.png', content_type: 'image/png')
        movie1.save!

        get '/media/autocomplete', params: { q: 'Wars', type: 'movie' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['thumbnail_url']).to include('cover.png')

        temp_file.close
        temp_file.unlink
      end
    end

    context 'with albums' do
      let!(:album) do
        Album.create!(title: 'Abbey Road', artist: 'The Beatles', release_year: 1969, genre: 'Rock', user: user)
      end

      it 'returns matching albums' do
        get '/media/autocomplete', params: { q: 'abbey', type: 'album' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['title']).to eq('Abbey Road')
        expect(json.first['artist']).to eq('The Beatles')
      end
    end

    context 'with comics' do
      let!(:comic) do
        Comic.create!(title: 'Watchmen', writer: 'Alan Moore', artist: 'Dave Gibbons', publisher: 'DC', issue_number: 1,
                      user: user)
      end

      it 'returns matching comics' do
        get '/media/autocomplete', params: { q: 'watch', type: 'comic' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['title']).to eq('Watchmen')
        expect(json.first['writer']).to eq('Alan Moore')
        expect(json.first['publisher']).to eq('DC')
      end
    end

    context 'with tv shows' do
      let!(:tv_show) { TvShow.create!(title: 'Breaking Bad', network: 'AMC', user: user) }

      it 'returns matching TV shows' do
        get '/media/autocomplete', params: { q: 'break', type: 'tv_show' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['title']).to eq('Breaking Bad')
        expect(json.first['network']).to eq('AMC')
      end
    end

    context 'with video games' do
      let!(:video_game) do
        VideoGame.create!(
          title: 'Portal 2', developer: 'Valve', publisher: 'Valve',
          platform: 'PC', release_year: 2011, user: user
        )
      end

      it 'returns matching video games' do
        get '/media/autocomplete', params: { q: 'portal', type: 'video_game' }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.size).to eq(1)
        expect(json.first['title']).to eq('Portal 2')
        expect(json.first['developer']).to eq('Valve')
      end
    end
  end
end
