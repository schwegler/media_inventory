# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Category & Entity Performance', type: :request do
  before do
    5.times do |i|
      comic = Comic.create!(title: "Comic #{i}", writer: 'Writer A', artist: 'Artist B')
      ComicIssue.create!(comic: comic, issue_number: 1, title: "Issue #{i}", credits: [{ 'name' => 'Writer A', 'role' => 'writer' }])
    end
  end

  it 'has a bounded query count when rendering category index' do
    queries = 0
    callback = ->(_name, _started, _finished, _unique_id, payload) {
      queries += 1 unless payload[:name] == 'SCHEMA'
    }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      get categories_path
    end

    expect(response).to have_http_status(:ok)
    expect(queries).to be < 35
  end

  it 'has a bounded query count when rendering category show page' do
    queries = 0
    callback = ->(_name, _started, _finished, _unique_id, payload) {
      queries += 1 unless payload[:name] == 'SCHEMA'
    }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      get category_item_path(category_type: 'comic-creators', name: 'Writer A')
    end

    expect(response).to have_http_status(:ok)
    expect(queries).to be < 20
  end
end
