# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Collections', type: :request do
  describe 'GET /show' do
    let!(:user) do
      User.create!(name: 'Test', email: 'test@example.com', password: 'password123', password_confirmation: 'password123')
    end

    context 'when the user is confirmed' do
      before do
        user.update!(confirmed_at: Time.current)
      end

      let!(:public_album) do
        LibraryItem.create!(user: user, item: Album.find_or_create_by!(title: 'Public Album'), is_public: true,
                            is_collected: true)
      end
      let!(:private_album) do
        LibraryItem.create!(user: user, item: Album.find_or_create_by!(title: 'Private Album'), is_public: false,
                            is_collected: true)
      end

      let!(:public_comic) do
        LibraryItem.create!(user: user, item: Comic.find_or_create_by!(title: 'Public Comic'), is_public: true,
                            is_collected: true)
      end
      let!(:private_comic) do
        LibraryItem.create!(user: user, item: Comic.find_or_create_by!(title: 'Private Comic'), is_public: false,
                            is_collected: true)
      end

      let!(:public_movie) do
        LibraryItem.create!(user: user, item: Movie.find_or_create_by!(title: 'Public Movie'), is_public: true,
                            is_collected: true)
      end
      let!(:private_movie) do
        LibraryItem.create!(user: user, item: Movie.find_or_create_by!(title: 'Private Movie'), is_public: false,
                            is_collected: true)
      end

      let!(:public_tv_show) do
        LibraryItem.create!(user: user, item: TvShow.find_or_create_by!(title: 'Public TV Show'), is_public: true,
                            is_collected: true)
      end
      let!(:private_tv_show) do
        LibraryItem.create!(user: user, item: TvShow.find_or_create_by!(title: 'Private TV Show'), is_public: false,
                            is_collected: true)
      end

      let!(:public_video_game) do
        LibraryItem.create!(user: user, item: VideoGame.find_or_create_by!(title: 'Public Video Game'), is_public: true,
                            is_collected: true)
      end
      let!(:private_video_game) do
        LibraryItem.create!(user: user, item: VideoGame.find_or_create_by!(title: 'Private Video Game'), is_public: false,
                            is_collected: true)
      end

      it 'returns http success' do
        get "/collections/#{user.id}"
        expect(response).to have_http_status(:success)
      end

      it 'displays only public collections for the user' do
        get "/collections/#{user.id}"

        expect(response.body).to include('Public Album')
        expect(response.body).not_to include('Private Album')

        expect(response.body).to include('Public Comic')
        expect(response.body).not_to include('Private Comic')

        expect(response.body).to include('Public Movie')
        expect(response.body).not_to include('Private Movie')

        expect(response.body).to include('Public TV Show')
        expect(response.body).not_to include('Private TV Show')

        expect(response.body).to include('Public Video Game')
        expect(response.body).not_to include('Private Video Game')
      end

      it 'is optimized to avoid N+1 queries when loading collection page' do
        # Record queries for 1 item per category (already created in let! blocks)
        query_count_base = 0
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          query_count_base += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].include?('PRAGMA')
        end
        get "/collections/#{user.id}"
        ActiveSupport::Notifications.unsubscribe(subscriber)

        # Create more items
        4.times do |i|
          LibraryItem.create!(user: user, is_public: true, is_collected: true,
                              item: Album.create!(title: "Extra Album #{i}"))
          LibraryItem.create!(user: user, is_public: true, is_collected: true,
                              item: Comic.create!(title: "Extra Comic #{i}"))
          LibraryItem.create!(user: user, is_public: true, is_collected: true,
                              item: Movie.create!(title: "Extra Movie #{i}"))
          LibraryItem.create!(user: user, is_public: true, is_collected: true,
                              item: TvShow.create!(title: "Extra TV Show #{i}"))
          LibraryItem.create!(user: user, is_public: true, is_collected: true,
                              item: VideoGame.create!(title: "Extra Game #{i}"))
        end

        # Record queries for 5 items per category
        query_count_after = 0
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          query_count_after += 1 unless payload[:name] == 'SCHEMA' || payload[:sql].include?('PRAGMA')
        end
        get "/collections/#{user.id}"
        ActiveSupport::Notifications.unsubscribe(subscriber)

        # Assert query counts are constant and do not grow with N
        expect(query_count_after).to eq(query_count_base)
      end

      it 'safely and successfully filters the collection items using search term without database errors' do
        get "/collections/#{user.id}", params: { q: 'Public' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Public Album')
        expect(response.body).not_to include('Extra Album')

        get "/collections/#{user.id}", params: { q: 'Non-existent' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('No items found matching')
        expect(response.body).not_to include('Public Album')
      end
    end

    context 'when the user is unconfirmed' do
      before do
        user.update!(confirmed_at: nil)
      end

      let!(:public_album) do
        LibraryItem.create!(user: user, item: Album.find_or_create_by!(title: 'Public Album'), is_public: true,
                            is_collected: true)
      end

      it 'returns http success' do
        get "/collections/#{user.id}"
        expect(response).to have_http_status(:success)
      end

      it 'does not display collections and shows a warning message' do
        get "/collections/#{user.id}"

        expect(response.body).not_to include('Public Album')
        expect(response.body).to include('This user&#39;s collection is not public because their account is unconfirmed.')
      end
    end
  end
end
