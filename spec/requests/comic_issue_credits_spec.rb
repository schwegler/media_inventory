# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comic Issue Credits', type: :request do
  let!(:comic) { Comic.create!(title: 'Ghost Rider', publisher: 'Marvel') }
  let!(:issue) do
    ComicIssue.create!(
      comic: comic,
      issue_number: 1,
      title: 'Resurrection',
      credits: [
        { 'name' => 'Howard Mackie', 'role' => 'writer' },
        { 'name' => 'Javier Saltares', 'role' => 'penciler' },
        { 'name' => 'Mark Texeira', 'role' => 'inker' },
        { 'name' => 'Gregory Wright', 'role' => 'colorist' }
      ]
    )
  end

  it 'creates MetadataCredit associations for comic issue creators' do
    expect(issue.metadata_credits.count).to eq(4)
    creators = issue.metadata_entities.pluck(:name)
    expect(creators).to include('Howard Mackie', 'Javier Saltares', 'Mark Texeira', 'Gregory Wright')
  end

  it 'renders links for comic issue creator names on issue page' do
    get comic_issue_path(issue)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Howard Mackie')
    expect(response.body).to include('/entities/')
  end
end
