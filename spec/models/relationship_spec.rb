# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Relationship, type: :model do
  let(:follower) { User.create(name: 'Follower', email: 'follower@example.com', password: 'password') }
  let(:followed) { User.create(name: 'Followed', email: 'followed@example.com', password: 'password') }
  let(:relationship) { follower.active_relationships.build(followed_id: followed.id) }

  it 'should be valid' do
    expect(relationship).to be_valid
  end

  describe 'follower methods' do
    it 'should respond to follower' do
      expect(relationship).to respond_to(:follower)
    end

    it 'should respond to followed' do
      expect(relationship).to respond_to(:followed)
    end

    it 'should have the right follower' do
      expect(relationship.follower).to eq(follower)
    end

    it 'should have the right followed' do
      expect(relationship.followed).to eq(followed)
    end
  end

  describe 'validations' do
    it 'should require a follower_id' do
      relationship.follower_id = nil
      expect(relationship).not_to be_valid
    end

    it 'should require a followed_id' do
      relationship.followed_id = nil
      expect(relationship).not_to be_valid
    end
  end
end
