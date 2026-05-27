# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoviesController, type: :controller do
  describe 'GET #index' do
    it 'returns a success response and assigns @movies' do
      movies = double('movies')
      allow(Movie).to receive(:page).with('1').and_return(movies)

      get :index, params: { page: '1' }

      expect(response).to be_successful
      expect(assigns(:movies)).to eq(movies)
    end
  end

  describe 'GET #show' do
    it 'returns a success response and assigns @movie' do
      movie = double('movie')
      allow(Movie).to receive(:find).with('1').and_return(movie)

      get :show, params: { id: '1' }

      expect(response).to be_successful
      expect(assigns(:movie)).to eq(movie)
    end
  end

  describe '#resource_params' do
    let(:params) do
      ActionController::Parameters.new(
        movie: {
          title: 'Inception',
          director: 'Christopher Nolan',
          release_year: 2010,
          rating: 'PG-13',
          is_public: true,
          malicious_param: 'hack'
        }
      )
    end

    before do
      allow(controller).to receive(:params).and_return(params)
    end

    it 'permits valid attributes' do
      permitted = controller.send(:resource_params)
      expect(permitted.to_h).to eq(
        'title' => 'Inception',
        'director' => 'Christopher Nolan',
        'release_year' => 2010,
        'rating' => 'PG-13',
        'is_public' => true
      )
    end

    it 'filters out unpermitted attributes' do
      permitted = controller.send(:resource_params)
      expect(permitted).not_to have_key(:malicious_param)
    end
  end
end
