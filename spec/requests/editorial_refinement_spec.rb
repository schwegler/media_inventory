# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Editorial tracking and profile refinement', type: :request do
  let(:user) do
    User.create!(name: 'Reader', username: 'editorial_reader', email: 'editorial@example.test', password: 'password123')
  end

  def login
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  it 'offers the next active-pass entry beside the title without loading a long series' do
    show = TvShow.create!(title: 'Long-running story')
    library = LibraryItem.create!(user: user, item: show)
    TvEpisode.insert_all!(1003.times.map do |index|
      { tv_show_id: show.id, season: 1, episode: index + 1, name: "Chapter #{index + 1}", air_date: '2020-01-01' }
    end)
    pass = ConsumptionPasses.start(library)
    pass.entries.create!(item: show.tv_episodes.first, consumed_at: Time.current)
    login
    instantiated = 0
    callback = lambda do |*args|
      payload = args.last
      instantiated += payload[:record_count] if payload[:class_name] == 'TvEpisode'
    end
    ActiveSupport::Notifications.subscribed(callback, 'instantiation.active_record') { get tv_show_path(show) }
    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.at_css('.media-next-entry').text).to include('S1E2', 'Chapter 2', 'Mark watched')
    expect(document.css('#series-entries .series-entry').size).to eq(30)
    expect(instantiated).to be <= 32
    form = document.at_css('.media-next-entry form')
    expect(form['method']).to eq('post')
    expect(form.at_css('input[name="tv_episode[consumed]"]')['value']).to eq('true')
    expect(form.at_css('input[name="_method"]')['value']).to eq('patch')
  end

  it 'requires a deliberate disclosure for an upcoming title action and omits it for other viewers' do
    show = TvShow.create!(title: 'Tomorrow’s story')
    library = LibraryItem.create!(user: user, item: show)
    show.tv_episodes.create!(season: 1, episode: 1, name: 'Tomorrow', air_date: Date.tomorrow)
    ConsumptionPasses.start(library)
    login
    get tv_show_path(show)
    document = Nokogiri::HTML(response.body)
    disclosure = document.at_css('.media-next-entry details.media-early-log')
    expect(disclosure).to be_present
    expect(disclosure['open']).to be_nil
    expect(disclosure.at_css('summary').text).to include('Log an early watch')
    expect(disclosure.at_css('form')).to be_present
    delete logout_path
    get tv_show_path(show)
    expect(Nokogiri::HTML(response.body).at_css('.media-next-entry')).to be_nil
  end

  it 'exhibits explicit public favorites without exposing their private library reviews or ratings' do
    items = 5.times.map { |index| Movie.create!(title: "Favorite #{index}") }
    items.each do |item|
      LibraryItem.create!(user: user, item: item, rating: '0.5', review: 'PRIVATE EDITORIAL REVIEW', is_public: false)
    end
    FavoriteShelf.create!(user: user, category: 'overall', picks: items.map { |item| { type: 'Movie', id: item.id } })
    get user_path(user)
    follow_redirect! if response.redirect?
    document = Nokogiri::HTML(response.body)
    expect(document.css('.profile-favorites-art a').map { |link| link['title'] }).to eq(items.first(3).map(&:title))
    expect(response.body).not_to include('PRIVATE EDITORIAL REVIEW')
    expect(document.at_css('.profile-favorites').text).not_to include('0.5')
  end
end
