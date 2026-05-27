# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoviesController, type: :controller do
  describe 'GET #index' do
    it 'returns a success response' do
      get :index
      expect(response).to be_successful
    end
  end

  describe 'GET #show' do
    let(:movie) { Movie.create!(title: 'Test Movie') }

    it 'returns a success response' do
      get :show, params: { id: movie.id }
      expect(response).to be_successful
    end
  end

  describe '#resource_params' do
    let(:params) do
      ActionController::Parameters.new(
        movie: {
          title: 'The Matrix',
          director: 'Wachowskis',
          release_year: 1999,
          rating: 'R',
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
        'title' => 'The Matrix',
        'director' => 'Wachowskis',
        'release_year' => 1999,
        'rating' => 'R',
        'is_public' => true
      )
    end

    it 'filters out unpermitted attributes' do
      permitted = controller.send(:resource_params)
      expect(permitted).not_to have_key(:malicious_param)
    end
  end
end
