# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Issue and episode metadata', type: :request do
  it 'shows issue-specific artists and story details on the issue and series pages' do
    comic = Comic.create!(title: 'A comic', artist: 'Series artist')
    issue = comic.comic_issues.create!(issue_number: 1, title: 'An issue',
                                       credits: [{ name: 'Issue artist', role: 'penciler, inker' }],
                                       metadata_details: { 'Story arcs' => 'An arc' })
    [comic_issue_path(issue), comic_path(comic)].each do |path|
      get path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Issue artist', 'An arc', 'Penciler, inker')
    end
  end

  it 'shows guest characters and episode crew on the episode and show pages' do
    show = TvShow.create!(title: 'A show')
    episode = show.tv_episodes.create!(season: 1, episode: 1, name: 'Pilot',
                                       credits: [{ name: 'Guest actor', role: 'Guest star', character: 'The mayor' },
                                                 { name: 'Pilot writer', role: 'Writer' }],
                                       metadata_details: { 'Runtime' => '44 minutes' })
    [tv_episode_path(episode), tv_show_path(show)].each do |path|
      get path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Guest actor as The mayor', 'Pilot writer', '44 minutes')
    end
  end
end
