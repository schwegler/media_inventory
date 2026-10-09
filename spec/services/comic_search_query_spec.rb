# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComicSearchQuery do
  it 'ranks exact titles above collections, normalizing punctuation and the leading article' do
    results = [{ title: 'Uncanny X-Men Omnibus', release_year: '2025' },
               { title: 'The Uncanny X-Men (1981)', release_year: '1981', is_local: true },
               { title: 'Uncanny X-Men', release_year: '2024', source: 'ComicVine' }]
    expect(described_class.new('uncanny x men').rank(results).map { |result| result[:release_year] })
      .to eq(%w[2024 1981 2025])
  end

  it 'keeps numbers that are part of a series title' do
    query = described_class.new('Spider-Man 2099')
    expect(query.title).to eq('Spider-Man 2099')
    expect(query.year).to be_nil
    expect(described_class.new('2000 AD').year).to be_nil
  end
end
