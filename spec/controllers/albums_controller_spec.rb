# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlbumsController, type: :controller do
  describe '#resource_params' do
    let(:params) do
      ActionController::Parameters.new(
        album: {
          title: 'Thriller',
          artist: 'Michael Jackson',
          release_year: 1982,
          genre: 'Pop',
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
        'title' => 'Thriller',
        'artist' => 'Michael Jackson',
        'release_year' => 1982,
        'genre' => 'Pop',
        'is_public' => true
      )
    end

    it 'filters out unpermitted attributes' do
      permitted = controller.send(:resource_params)
      expect(permitted).not_to have_key(:malicious_param)
    end
  end
end
