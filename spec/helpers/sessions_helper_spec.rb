# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsHelper, type: :helper do
  let(:user) do
    User.create!(name: 'Test User', email: 'test@example.com', password: 'password123',
                 password_confirmation: 'password123')
  end

  describe '#log_in' do
    it 'logs in the given user' do
      expect(helper).to receive(:reset_session)
      helper.log_in(user)
      expect(session[:user_id]).to eq(user.id)
    end
  end

  describe '#current_user' do
    context 'when session contains user_id' do
      before do
        session[:user_id] = user.id
      end

      it 'returns the user' do
        expect(helper.current_user).to eq(user)
      end

      it 'memoizes the user' do
        expect(User).to receive(:find_by).once.and_return(user)
        helper.current_user
        helper.current_user
      end
    end

    context 'when session does not contain user_id' do
      it 'returns nil' do
        expect(helper.current_user).to be_nil
      end
    end
  end

  describe '#current_user?' do
    before do
      session[:user_id] = user.id
    end

    it 'returns true if the given user is the current user' do
      expect(helper.current_user?(user)).to be true
    end

    it 'returns false if the given user is not the current user' do
      other_user = User.create!(name: 'Other User', email: 'other@example.com', password: 'password123',
                                password_confirmation: 'password123')
      expect(helper.current_user?(other_user)).to be false
    end
  end

  describe '#logged_in?' do
    it 'returns true if the user is logged in' do
      session[:user_id] = user.id
      expect(helper.logged_in?).to be true
    end

    it 'returns false if the user is not logged in' do
      expect(helper.logged_in?).to be false
    end
  end

  describe '#log_out' do
    before do
      session[:user_id] = user.id
      helper.current_user # To memoize @current_user
    end

    it 'logs out the current user' do
      helper.log_out
      expect(session[:user_id]).to be_nil
      expect(helper.instance_variable_get(:@current_user)).to be_nil
      expect(helper.current_user).to be_nil
    end
  end
end
