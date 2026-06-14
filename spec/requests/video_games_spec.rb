# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'VideoGames', type: :request do
  let!(:user) do
    User.create(name: 'Example User', email: 'user@example.com', password: 'password123',
                password_confirmation: 'password123')
  end

  describe 'GET /video_games' do
    it 'works! (now write some real specs)' do
      get video_games_path
      expect(response).to have_http_status(200)
    end

    context 'with pagination' do
      before do
        30.times { |i| VideoGame.create!(title: "Game #{i}") }
      end

      it 'returns the first page of games' do
        get video_games_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Game 0')
        expect(response.body).to include('Game 24')
        expect(response.body).not_to include('Game 25')
      end

      it 'returns the second page of games' do
        get video_games_path(page: 2)
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('Game 0')
        expect(response.body).to include('Game 25')
        expect(response.body).to include('Game 29')
      end
    end
  end

  describe 'GET /video_games/new' do
    context 'when not logged in' do
      it 'redirects to login' do
        get new_video_game_path
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
      end

      it 'returns http success' do
        get new_video_game_path
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'POST /video_games' do
    context 'when not logged in' do
      it 'redirects to login' do
        post video_games_path, params: { video_game: { title: 'New Game' } }
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
      end

      context 'with valid parameters' do
        it 'creates a new video game' do
          expect do
            post video_games_path, params: { video_game: { title: 'New Game' } }
          end.to change(VideoGame, :count).by(1)
          expect(response).to redirect_to(VideoGame.last)
        end

        it 'creates a new video game with a custom cover image' do
          temp_file = Tempfile.new(['test_cover', '.png'])
          temp_file.write('dummy content')
          temp_file.rewind
          uploaded_file = fixture_file_upload(temp_file.path, 'image/png')

          expect do
            post video_games_path, params: { video_game: { title: 'New Game with Cover', cover_image: uploaded_file } }
          end.to change(VideoGame, :count).by(1)

          game = VideoGame.last
          expect(game.cover_image).to be_attached
          expect(game.cover_image.filename.to_s).to include('test_cover')

          temp_file.close
          temp_file.unlink
        end
      end

      context 'with invalid parameters' do
        it 'does not create a new video game' do
          expect do
            post video_games_path, params: { video_game: { title: '' } }
          end.not_to change(VideoGame, :count)
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('New Video Game')
        end
      end
    end
  end

  describe 'GET /video_games/:id' do
    context 'with a valid video game' do
      let!(:game) do
        VideoGame.create!(
          title: 'Portal 2',
          developer: 'Valve',
          release_year: 2011,
          rating: '5.0'
        )
      end

      it 'returns a success response and displays the game details' do
        get video_game_path(game)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Portal 2')
        expect(response.body).to include('Valve')
        expect(response.body).to include('2011')
      end
    end

    context 'with an invalid game id' do
      it 'returns a not found response' do
        get video_game_path('0')
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
