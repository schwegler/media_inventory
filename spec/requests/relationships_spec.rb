# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Relationships', type: :request do
  let!(:user) do
    User.create!(name: 'Test', email: "test#{SecureRandom.hex(4)}@test.com", password: 'password',
                 password_confirmation: 'password')
  end
  let!(:other_user) do
    User.create!(name: 'Other', email: "other#{SecureRandom.hex(4)}@test.com", password: 'password',
                 password_confirmation: 'password')
  end

  describe 'POST /relationships' do
    it 'creates a relationship when logged in' do
      post login_path, params: { session: { email: user.email, password: 'password' } }
      expect do
        post relationships_path, params: { followed_id: other_user.id }
      end.to change(Relationship, :count).by(1)
    end
  end

  describe 'DELETE /relationships/:id' do
    let!(:relationship) { user.active_relationships.create!(followed_id: other_user.id) }

    it 'destroys a relationship when logged in' do
      post login_path, params: { session: { email: user.email, password: 'password' } }
      expect do
        delete relationship_path(relationship)
      end.to change(Relationship, :count).by(-1)
    end

    it 'prevents destroying another user relationship record (IDOR protection)' do
      other_user_relationship = other_user.active_relationships.create!(followed_id: user.id)
      post login_path, params: { session: { email: user.email, password: 'password' } }
      expect do
        delete relationship_path(other_user_relationship)
      end.not_to change(Relationship, :count)
      expect(response).to redirect_to(root_path)
    end
  end
end
