# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnalyticsHelper, type: :helper do
  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(request).to receive_messages(get?: true, host: 'trove.schweg.xyz', ssl?: true,
                                       query_parameters: {}, user_agent: 'Browser')
    allow(request).to receive(:format).and_return(double(html?: true))
    allow(helper).to receive_messages(logged_in?: false, hotwire_native_app?: false,
                                      controller_name: 'landing', action_name: 'index')
  end

  it 'uses fixed public home metadata' do
    expect(helper.public_analytics_page).to eq(path: '/', title: 'Trove', type: 'home', group: 'public')
  end

  it 'aggregates public shelves without exposing their handles' do
    allow(helper).to receive_messages(controller_name: 'shelves', action_name: 'show')
    expect(helper.public_analytics_page).to eq(path: '/public_shelf', title: 'Public shelf',
                                               type: 'public_shelf', group: 'public')
  end

  it 'excludes authenticated users, native clients, queries and noncanonical hosts' do
    %i[logged_in? hotwire_native_app?].each do |method|
      allow(helper).to receive(method).and_return(true)
      expect(helper.public_analytics_page).to be_nil
      allow(helper).to receive(method).and_return(false)
    end
    allow(request).to receive(:query_parameters).and_return(email: 'private@example.test')
    expect(helper.public_analytics_page).to be_nil
    allow(request).to receive(:query_parameters).and_return({})
    allow(request).to receive(:host).and_return('staging.example.test')
    expect(helper.public_analytics_page).to be_nil
  end

  it 'excludes auth, settings, search, user libraries and write actions by default' do
    %w[sessions settings search users collections admin].each do |name|
      allow(helper).to receive_messages(controller_name: name, action_name: 'show')
      expect(helper.public_analytics_page).to be_nil
    end
    allow(helper).to receive_messages(controller_name: 'movies', action_name: 'update')
    expect(helper.public_analytics_page).to be_nil
  end

  it 'excludes unsuccessful responses' do
    allow(response).to receive(:status).and_return(404)
    expect(helper.public_analytics_page).to be_nil
  end

  it 'describes catalog pages without item titles or IDs' do
    allow(helper).to receive_messages(controller_name: 'movies', action_name: 'show')
    expect(helper.public_analytics_page).to eq(path: '/movies/show', title: 'Trove movies',
                                               type: 'catalog', group: 'movies')
  end
end
