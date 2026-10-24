# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaSourcesHelper, type: :helper do
  around do |example|
    previous = Rails.configuration.x.amazon_associates_tag
    Rails.configuration.x.amazon_associates_tag = 'schweg-20'
    example.run
  ensure
    Rails.configuration.x.amazon_associates_tag = previous
  end

  def amazon(item, eligible: false)
    helper.media_source_links(item, amazon_eligible: eligible).last
  end

  it 'leaves imported metadata and all default callers untagged' do
    item = Book.new(title: 'Dracula', author: 'Bram Stoker')
    expect(amazon(item)).to include(label: 'Search Amazon', paid: false)
    expect(URI.decode_www_form(URI(amazon(item)[:url]).query)).to eq([%w[k Dracula]])
  end

  it 'encodes literal query text without injecting or duplicating a tag' do
    item = Book.new(title: 'Café & #haunt? tag=hurricaneplay-20 + 雪')
    source = amazon(item, eligible: true)
    expect(source).to include(label: 'Search Amazon (paid link)', paid: true)
    expect(URI.decode_www_form(URI(source[:url]).query)).to eq([
                                                                 ['k', item.title], %w[tag schweg-20]
                                                               ])
  end

  it 'fails closed for blank, missing, malformed and retired configuration' do
    [nil, '', ' ', 'hurricaneplay-20', 'schweg-20&tag=other-20'].each do |tag|
      Rails.configuration.x.amazon_associates_tag = tag
      source = amazon(Book.new(title: 'Dracula'), eligible: true)
      expect(source).to include(label: 'Search Amazon', paid: false)
      expect(URI.decode_www_form(URI(source[:url]).query).map(&:first)).to eq(['k'])
    end
  end

  it 'preserves provider and ordinary search links' do
    sources = helper.media_source_links(Movie.new(title: 'Alien & Aliens', external_url: 'https://tv.apple.com/example'))
    labels = ['View on Apple TV', 'Search JustWatch', 'Google Search Options', 'Search Amazon']
    expect(sources.map { |source| source[:label] }).to eq(labels)
  end
end
