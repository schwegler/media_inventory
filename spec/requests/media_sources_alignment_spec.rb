# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Find This Title Links Alignment', type: :request do
  let!(:movie) { Movie.create!(title: 'Dune') }

  it 'renders structured icon, label, and external link layout for all rows' do
    get movie_path(movie)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="media-source-icon"')
    expect(response.body).to include('class="media-source-label"')
    expect(response.body).to include('Find this title')
  end

  [Movie, TvShow, Book, Album, Comic, VideoGame].each do |model|
    it "renders an official source for #{model.name} without crashing" do
      source_url = 'https://example.com/catalog/title'
      item = model.create!(title: 'Official source', external_url: source_url)

      get polymorphic_path(item)

      expect(response).to have_http_status(:ok)
      link = Nokogiri::HTML(response.body).at_css('.btn-stream-source')
      expect(link['href']).to eq(source_url)
      expect(link.text.strip).to eq('View Official Source')
      expect(link.at_css('.ui-icon--globe')).to be_present
      expect(link['target']).to eq('_blank')
      expect(link['rel']).to include('noopener')
    end
  end
end
