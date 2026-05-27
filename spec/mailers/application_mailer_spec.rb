# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationMailer, type: :mailer do
  describe 'defaults' do
    it 'sets the default from address' do
      expect(ApplicationMailer.default_params[:from]).to eq('from@example.com')
    end

    it 'sets the default layout' do
      expect(ApplicationMailer._layout).to eq('mailer')
    end
  end
end
