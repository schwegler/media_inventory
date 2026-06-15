# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TvShow, type: :model do
  it 'is valid with a title' do
    tv_show = TvShow.new(title: 'Breaking Bad', season: 1, episode: 1)
    expect(tv_show).to be_valid
  end

  it 'is invalid without a title' do
    tv_show = TvShow.new(title: nil)
    expect(tv_show).to_not be_valid
  end
end
