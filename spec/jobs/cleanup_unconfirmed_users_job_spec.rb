# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CleanupUnconfirmedUsersJob, type: :job do
  describe '#perform' do
    let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }

    context 'when the user is confirmed' do
      before do
        user.update!(confirmed_at: Time.current)
        user.update_columns(created_at: 50.minutes.ago)
      end

      it 'does not destroy the user' do
        expect do
          described_class.new.perform(user.id)
        end.not_to change(User, :count)
      end
    end

    context 'when the user is unconfirmed but created recently' do
      before do
        user.update_columns(created_at: 10.minutes.ago)
      end

      it 'does not destroy the user' do
        expect do
          described_class.new.perform(user.id)
        end.not_to change(User, :count)
      end
    end

    context 'when the user is unconfirmed and created more than 45 minutes ago' do
      before do
        user.update_columns(created_at: 50.minutes.ago)
      end

      it 'destroys the user' do
        expect do
          described_class.new.perform(user.id)
        end.to change(User, :count).by(-1)
      end
    end

    context 'when the user does not exist' do
      it 'handles it gracefully without raising an error' do
        expect do
          described_class.new.perform(999_999)
        end.not_to raise_error
      end
    end
  end
end
