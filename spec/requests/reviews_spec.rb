# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reviews', type: :request do
  let!(:user) do
    User.create!(name: 'Reviewer', email: 'reviewer@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end
  let!(:tv_show) { TvShow.create!(title: 'Stargate SG-1') }
  let!(:show_library_item) { LibraryItem.create!(user: user, item: tv_show) }
  let!(:tv_episode) { tv_show.tv_episodes.create!(name: '2010', season: 4, episode: 16) }
  let!(:movie) { Movie.create!(title: 'The Matrix') }

  context 'when not logged in' do
    it 'redirects GET /review/edit to login' do
      get edit_review_path(item_type: 'TvEpisode', item_id: tv_episode.id)
      expect(response).to redirect_to(login_path)
    end

    it 'redirects PATCH /review to login' do
      patch review_path, params: { item_type: 'TvEpisode', item_id: tv_episode.id, review: 'Great' }
      expect(response).to redirect_to(login_path)
    end
  end

  context 'when logged in' do
    before do
      post login_path, params: { session: { email: user.email, password: 'password123' } }
    end

    describe 'GET /review/edit' do
      it 'renders modal for an episode' do
        LibraryItem.create!(user: user, item: tv_episode, rating: '4.0', review: 'Awesome episode', consumed: true)

        get edit_review_path(item_type: 'TvEpisode', item_id: tv_episode.id), headers: { 'Turbo-Frame' => 'modal' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Review Episode 16')
        expect(response.body).to include('2010')
        expect(response.body).to include('Awesome episode')
        expect(response.body).to include('4.0')
      end

      it 'renders modal for a show' do
        show_library_item.update!(rating: '5.0', review: 'Classic sci-fi series')

        get edit_review_path(item_type: 'TvShow', item_id: tv_show.id), headers: { 'Turbo-Frame' => 'modal' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Review')
        expect(response.body).to include('Stargate SG-1')
        expect(response.body).to include('Classic sci-fi series')
      end

      it 'rejects invalid item types' do
        get edit_review_path(item_type: 'User', item_id: user.id)
        expect(response).to redirect_to(root_path)
      end
    end

    describe 'PATCH /review' do
      it 'updates an episode review via turbo stream and closes modal' do
        ep_lib = LibraryItem.create!(user: user, item: tv_episode, rating: '3.0', review: 'Okay', consumed: true)

        patch review_path, params: {
          item_type: 'TvEpisode',
          item_id: tv_episode.id,
          rating: '4.5',
          review: 'Actually amazing!',
          is_public: '1'
        }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include("tv_episode_#{tv_episode.id}")

        ep_lib.reload
        expect(ep_lib.rating).to eq('4.5')
        expect(ep_lib.review).to eq('Actually amazing!')
        expect(ep_lib.is_public).to be(true)
      end

      it 'updates a show review via turbo stream and closes modal' do
        patch review_path, params: {
          item_type: 'TvShow',
          item_id: tv_show.id,
          rating: '5.0',
          review: 'One of my all-time favorites',
          is_public: '0'
        }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        expect(response.body).to include('turbo-stream action="update" target="modal"')
        expect(response.body).to include("media_actions_tv_show_#{tv_show.id}")

        show_library_item.reload
        expect(show_library_item.rating).to eq('5.0')
        expect(show_library_item.review).to eq('One of my all-time favorites')
      end

      it 'allows clearing review and rating' do
        ep_lib = LibraryItem.create!(user: user, item: tv_episode, rating: '4.0', review: 'Good', consumed: true)

        patch review_path, params: {
          item_type: 'TvEpisode',
          item_id: tv_episode.id,
          rating: '',
          review: ''
        }, as: :turbo_stream

        expect(response).to have_http_status(:success)
        ep_lib.reload
        expect(ep_lib.rating).to be_nil
        expect(ep_lib.review).to be_nil
      end
    end

    describe 'UI conditional rendering' do
      it 'does not show inline review form for reviewed episode, shows edit review modal link instead' do
        LibraryItem.create!(user: user, item: tv_episode, rating: '4.0', consumed: true)

        get tv_show_path(tv_show)
        expect(response).to have_http_status(:success)
        # Rating is displayed
        expect(response.body).to include('4.0 ★')
        # Edit review modal link is present
        expect(response.body).to include('data-turbo-frame="modal"')
        expect(response.body).to match(%r{/review/edit\?[^"]*item_type=TvEpisode})
        # The inline form inputs are not displayed
        expect(response.body).not_to include("child-review-#{tv_episode.id}")
      end

      it 'offers a review drawer for unreviewed episodes without an inline form' do
        get tv_show_path(tv_show)
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("child-review-#{tv_episode.id}")
        expect(response.body).to include('Write review')
      end

      it 'does not show inline review form for reviewed show, shows edit review modal link instead' do
        show_library_item.update!(rating: '4.5', review: 'Great series')

        get tv_show_path(tv_show)
        expect(response).to have_http_status(:success)
        # Edit review link is present
        expect(response.body).to include('data-turbo-frame="modal"')
        expect(response.body).to match(%r{/review/edit\?[^"]*item_type=TvShow})
        # Inline review form is hidden
        expect(response.body).not_to include("library-review-#{tv_show.id}")
      end

      it 'shows inline review form for unreviewed show' do
        get tv_show_path(tv_show)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("library-review-#{tv_show.id}")
      end
    end
  end
end
