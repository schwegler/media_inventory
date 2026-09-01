# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_media_actions_and_stream.html.erb', type: :view do
  let(:movie) { Movie.create!(title: 'Inception', release_year: 2010, external_url: 'https://example.com/inception') }

  it 'renders external links with target="_blank" and rel="noopener noreferrer"' do
    render partial: 'shared/media_actions_and_stream', locals: { item: movie }

    expect(rendered).to have_link('View Official Source', href: 'https://example.com/inception')

    doc = Nokogiri::HTML.fragment(rendered)
    blank_links = doc.css('a[target="_blank"]')
    expect(blank_links).not_to be_empty

    blank_links.each do |link|
      expect(link['rel']).to include('noopener')
      expect(link['rel']).to include('noreferrer')
    end
  end
end
