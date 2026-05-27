# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WrestlingEventsController, type: :controller do
  describe '#resource_params' do
    let(:params) do
      ActionController::Parameters.new(
        wrestling_event: {
          title: 'WrestleMania',
          promotion: 'WWE',
          date: '2024-04-06',
          venue: 'Lincoln Financial Field',
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
        'title' => 'WrestleMania',
        'promotion' => 'WWE',
        'date' => '2024-04-06',
        'venue' => 'Lincoln Financial Field',
        'is_public' => true
      )
    end

    it 'filters out unpermitted attributes' do
      permitted = controller.send(:resource_params)
      expect(permitted).not_to have_key(:malicious_param)
    end
  end
end
