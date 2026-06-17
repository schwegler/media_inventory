# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Likes', type: :request do
  let!(:user) do
    User.create!(
      name: 'Example User',
      email: 'user@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  let!(:movie) do
    Movie.create!(
      title: 'Inception'
    )
  end

  describe 'POST /likes/toggle' do
    context 'when not logged in' do
      it 'redirects to login' do
        post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: movie.id }
        expect(response).to redirect_to(login_path)
      end
    end

    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: 'password123' } }
      end

      context 'with invalid parameters' do
        it 'returns bad request for invalid likeable type' do
          post toggle_like_path, params: { likeable_type: 'InvalidType', likeable_id: movie.id }
          expect(response).to have_http_status(:bad_request)
          expect(JSON.parse(response.body)['error']).to eq('Invalid likeable type')
        end

        it 'returns not found for non-existent likeable id' do
          post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: 9999 }
          expect(response).to have_http_status(:not_found)
          expect(JSON.parse(response.body)['error']).to eq('Likeable item not found')
        end
      end

      context 'with valid parameters' do
        it 'creates a new like when none exists' do
          expect do
            post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: movie.id }
          end.to change(Like, :count).by(1)

          expect(movie.likes.count).to eq(1)
          expect(movie.likes.first.user).to eq(user)
        end

        it 'removes a like when one already exists' do
          Like.create!(user: user, likeable: movie)
          expect(movie.likes.count).to eq(1)

          expect do
            post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: movie.id }
          end.to change(Like, :count).by(-1)

          expect(movie.likes.count).to eq(0)
        end

        context 'JSON format' do
          it 'returns JSON with liked status and likes count' do
            post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: movie.id }, as: :json
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['liked']).to be(true)
            expect(json['likes_count']).to eq(1)

            post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: movie.id }, as: :json
            expect(response).to have_http_status(:ok)
            json = JSON.parse(response.body)
            expect(json['liked']).to be(false)
            expect(json['likes_count']).to eq(0)
          end
        end

        context 'Turbo Stream format' do
          it 'renders a turbo stream replacement for the like button' do
            post toggle_like_path, params: { likeable_type: 'Movie', likeable_id: movie.id, format: :turbo_stream }
            expect(response.media_type).to eq('text/vnd.turbo-stream.html')
            expect(response.body).to include('turbo-stream action="replace" target="like_button_Movie_')
          end
        end
      end
    end
  end
end
