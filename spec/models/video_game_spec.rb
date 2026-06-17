# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VideoGame, type: :model do
  it 'is valid with a title' do
    game = VideoGame.new(title: 'Portal 2')
    expect(game).to be_valid
  end

  it 'is invalid without a title' do
    game = VideoGame.new(title: nil)
    expect(game).to_not be_valid
  end
end
