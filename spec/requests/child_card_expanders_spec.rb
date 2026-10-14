# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Child Card Detail Expanders', type: :request do
  let!(:show) { TvShow.create!(title: 'Severance', network: 'Apple TV+') }
  let!(:episode) do
    TvEpisode.create!(tv_show: show, season: 1, episode: 1, name: 'Good News About Hell', summary: 'Mark leads a team.')
  end

  it 'renders a single disclosure control per episode card with consistent Details label' do
    get tv_show_path(show)
    expect(response).to have_http_status(:ok)
    # Ensure there is only one details disclosure per episode card
    expect(response.body.scan('<details class="series-entry-details">').size).to eq(1)
    expect(response.body).not_to include('<details class="series-entry-metadata">')
    expect(response.body).to include('class="series-entry-toggle"')
    expect(response.body).to include('<span>Details</span>')
    expect(response.body).not_to include('Hide details')
  end
end
