# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Calendar-year soap episode pages', type: :request do
  it 'filters year-numbered seasons and paginates a 7,333-episode show without loading every episode' do
    show = TvShow.create!(title: 'Long-running soap fixture')
    TvEpisode.insert_all!(7333.times.map do |n|
      { tv_show_id: show.id, season: 1985 + (n / 175), episode: (n % 175) + 1, name: "Chapter #{n + 1}" }
    end)
    count = 0
    callback = lambda do |*args|
      payload = args.last
      count += payload[:record_count] if payload[:class_name] == 'TvEpisode'
    end
    ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') do
      get tv_show_path(show), params: { season: '2026', entries_page: '2', child_status: 'all' }
    end
    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.css('#series-entries .series-entry').size).to eq(30)
    expect(document.at_css('#season option[selected]')['value']).to eq('2026')
    expect(document.text).to include('158 matching episodes', '31–60 of 158')
    expect(count).to be <= 32
    get tv_show_path(show), params: { season: 'all', entries_page: '245', child_status: 'all' }
    expect(Nokogiri::HTML(response.body).css('#series-entries .series-entry').size).to eq(13)
    expect(response.body).to include('7333 matching episodes')
  end
end
