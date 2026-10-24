# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HalloweenReading do
  it 'requires an explicitly curated book and matching author' do
    expect(described_class.for_title(Book.new(title: 'Dracula', author: 'Bram Stoker'))).to include('diary entries')
    expect(described_class.for_title(Book.new(title: 'Frankenstein', author: 'Mary Shelley'))).to include('1818')
    expect(described_class.for_title(Book.new(title: 'Dracula', author: 'Someone else'))).to be_nil
    expect(described_class.for_title(Book.new(title: 'Dracula'))).to be_nil
    expect(described_class.for_title(Movie.new(title: 'Dracula'))).to be_nil
    expect(described_class.for_title(Book.new(title: 'Other book', author: 'Bram Stoker'))).to be_nil
  end
end
