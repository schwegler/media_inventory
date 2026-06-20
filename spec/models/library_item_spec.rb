# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LibraryItem, type: :model do
  it 'is valid with valid attributes' do
    user = User.create!(name: 'Test', email: "test_#{SecureRandom.hex(4)}@test.com", password: 'password',
                        password_confirmation: 'password')
    album = Album.create!(title: 'Test Album')
    item = LibraryItem.new(user: user, item: album)
    expect(item).to be_valid
  end
end
