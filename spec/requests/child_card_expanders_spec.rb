# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Child Card Detail Expanders', type: :request do
  let!(:show) { TvShow.create!(title: 'Severance', network: 'Apple TV+') }
  let!(:episode) do
    TvEpisode.create!(tv_show: show, season: 1, episode: 1, name: 'Good News About Hell', summary: 'Mark leads a team.')
  end

  let!(:comic) { Comic.create!(title: 'Saga', publisher: 'Image') }
  let!(:issue) do
    comic.comic_issues.create!(issue_number: 1, title: 'Chapter One', summary: 'Hazel is born.')
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

    # Non-nested interactive links: title link is outside summary
    page = Nokogiri::HTML(response.body)
    summary = page.at_css('.series-entry-details > summary.series-entry-toggle')
    expect(summary).to be_present
    expect(summary.at_css('a')).to be_nil
    expect(summary.at_css('button')).to be_nil
  end

  it 'renders a unified disclosure shell for comic issue cards with separate title link' do
    get comic_path(comic)
    expect(response).to have_http_status(:ok)
    expect(response.body.scan('<details class="series-entry-details">').size).to eq(1)
    expect(response.body).to include('class="series-entry-toggle"')
    expect(response.body).to include('<span>Details</span>')

    page = Nokogiri::HTML(response.body)
    title_link = page.at_css('.series-entry-title > a')
    expect(title_link).to be_present
    expect(title_link['href']).to eq(comic_issue_path(issue))

    summary = page.at_css('.series-entry-details > summary.series-entry-toggle')
    expect(summary).to be_present
    expect(summary['aria-label']).to eq('Details for #1: Chapter One')
    expect(summary.at_css('a')).to be_nil
  end
end
