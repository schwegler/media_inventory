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

  it 'uses a raw provider identity instead of another person with the same name' do
    rows = %w[111 222].map do |id|
      { 'name' => 'Alex Lee', 'role' => 'Writer', 'provider' => 'ComicVine:contributor', 'external_id' => id }
    end
    first, second = rows.map { |row| MetadataEntityResolver.call(row) }
    issue.metadata_credits.delete_all
    issue.update_columns(credits: [rows.first.merge('character' => 'The author')])

    get comic_issue_path(issue)

    credits = Nokogiri::HTML(response.body).at_css('.child-detail-credits')
    expect(credits.at_css('a')['href']).to eq(metadata_entity_path(first))
    expect(credits.to_html).not_to include(metadata_entity_path(second))
    expect(credits.text).to include('Alex Lee as The author')
  end

  it 'leaves ambiguous raw names unlinked and escapes supplied text' do
    %w[111 222].each do |id|
      MetadataEntityResolver.call('name' => 'Alex Lee', 'role' => 'Writer',
                                  'provider' => 'ComicVine:contributor', 'external_id' => id)
    end
    issue.metadata_credits.delete_all
    issue.update_columns(credits: [{ 'name' => 'Alex Lee', 'role' => 'Writer', 'character' => '<script>bad</script>' }])

    get comic_issue_path(issue)

    credits = Nokogiri::HTML(response.body).at_css('.child-detail-credits')
    expect(credits.css('a, script')).to be_empty
    expect(credits.text).to include('Alex Lee as <script>bad</script>')
  end
end
