# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiConfiguration, type: :model do
  it 'is valid with valid attributes' do
    config = ApiConfiguration.new(source_name: 'TMDB', base_url: 'https://api.themoviedb.org/3')
    expect(config).to be_valid
  end
end
