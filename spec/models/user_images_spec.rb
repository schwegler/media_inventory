# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'User Images', type: :model do
  let(:user) { User.create!(name: 'Image User', email: 'images@example.com', password: 'password') }

  it 'can have an avatar attached' do
    user.avatar.attach(io: File.open(Rails.root.join('public', 'favicon.ico')), filename: 'favicon.ico',
                       content_type: 'image/x-icon')
    expect(user.avatar).to be_attached
  end

  it 'can have a header banner attached' do
    user.header_banner.attach(io: File.open(Rails.root.join('public', 'favicon.ico')), filename: 'favicon.ico',
                              content_type: 'image/x-icon')
    expect(user.header_banner).to be_attached
  end
end
