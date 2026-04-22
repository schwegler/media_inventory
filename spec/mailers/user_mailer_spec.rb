# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserMailer, type: :mailer do
  describe 'otp_email' do
    let(:user) { User.create!(name: 'Test', email: 'test@example.com') }
    let(:mail) { UserMailer.otp_email(user) }

    before do
      user.update(login_token: '123456')
    end

    it 'renders the headers' do
      expect(mail.subject).to eq('Your One-Time Password')
      expect(mail.to).to eq(['test@example.com'])
    end

    it 'renders the body' do
      expect(mail.body.encoded).to match('123456')
    end
  end
end
