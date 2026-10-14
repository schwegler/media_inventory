# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Entity work pagination', type: :request do
  it 'counts and paginates each work once while retaining all selected roles' do
    entity = MetadataEntity.create!(kind: 'person', name: 'Shared Creator')
    comic = Comic.create!(title: 'Paginated series')
    49.times do |index|
      issue = comic.comic_issues.create!(issue_number: index + 1, title: "Story #{index + 1}")
      %w[Writer Editor].each do |role|
        MetadataCredit.create!(metadata_entity: entity, item: issue, role: role, source: 'test')
      end
    end
    get metadata_entity_path(entity, library: 'all')
    document = Nokogiri::HTML(response.body)
    expect(document.css('.entity-work-row').size).to eq(24)
    expect(document.at_css('.entity-credit-summary').text).to include('49 credited works')
    expect(document.at_css('.entity-work-role').text).to include('Editor', 'Writer')
    get metadata_entity_path(entity, library: 'all', page: 3)
    document = Nokogiri::HTML(response.body)
    expect(document.css('.entity-work-row').size).to eq(1)
    expect(document.at_css('.entity-work-title').text).to include('Story 49')
  end
end
