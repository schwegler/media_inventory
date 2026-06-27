# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  it 'is invalid with a password shorter than 8 characters' do
    user = User.new(name: 'Test User', email: 'short@example.com', password: 'abc', password_confirmation: 'abc')
    expect(user).not_to be_valid
    expect(user.errors[:password]).to include('is too short (minimum is 8 characters)')
  end

  it 'is valid with a password of 8 characters' do
    user = User.new(name: 'Test User', email: 'valid@example.com', password: 'password', password_confirmation: 'password')
    expect(user).to be_valid
  end
end
