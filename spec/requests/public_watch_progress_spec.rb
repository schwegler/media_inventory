# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Public watch progress boundaries', type: :request do
  let!(:owner) do
    User.create!(name: 'Watch owner', username: 'watch_owner', email: 'watch-owner@example.com',
                 password: 'password123', confirmed_at: Time.current)
  end
  let!(:visitor) do
    User.create!(name: 'Visitor', email: 'watch-visitor@example.com', password: 'password123', confirmed_at: Time.current)
  end

  def start_watch(title, visibility: nil)
    show = TvShow.create!(title: title)
    library = owner.library_items.create!(item: show, is_public: visibility, review: 'Private review sentinel', rating: 5)
    3.times { |n| show.tv_episodes.create!(name: "Chapter #{n + 1}", season: 1, episode: n + 1) }
    owner.library_items.create!(item: show.tv_episodes.first, consumed: true, consumed_at: '2020-02-03',
                                is_public: false, review: 'Private episode sentinel', rating: 1)
    [show, library]
  end

  def sign_in(user)
    post login_path, params: { session: { email: user.email, password: 'password123' } }
  end

  def expect_read_only_summary
    document = Nokogiri::HTML(response.body)
    expect(response).to have_http_status(:ok)
    expect(document.css('.in-progress-card').size).to eq(2)
    expect(document.css('.in-progress-progress-counts').map(&:text)).to all(include('1 / 3 episodes'))
    expect(document.css('.in-progress-next-link').map(&:text)).to all(eq('Chapter 2'))
    expect(document.css('.in-progress-log-form, .tracking-options, .in-progress-pass-badge')).to be_empty
    expect(response.body).not_to include('Private review sentinel', 'Private episode sentinel', '2020-02-03')
    expect(response.headers['Cache-Control']).to include('private', 'no-store')
  end

  it 'shows active TV summaries to guests, nonowners and public preview without publishing private details' do
    show, library = start_watch('Review marked private', visibility: false)
    ConsumptionPasses.dismiss(library.consumption_passes.sole)
    rewatch = ConsumptionPasses.start(library)
    rewatch.entries.create!(item: show.tv_episodes.first, consumed_at: Time.current)
    start_watch('Review visibility unset')
    _, dismissed = start_watch('Dismissed watch', visibility: false)
    ConsumptionPasses.dismiss(dismissed.consumption_passes.sole)
    [nil, visitor, owner].each do |viewer|
      sign_in(viewer) if viewer
      params = { tab: 'progress' }
      params[:preview] = 'public' if viewer == owner
      get handle_profile_path(owner.username), params: params
      expect_read_only_summary
      expect(response.body).not_to include('Dismissed watch')
      get handle_profile_path(owner.username), params: params.except(:tab)
      expect_read_only_summary
      delete logout_path if viewer
    end
    expect(owner.library_items.where(is_public: false).count).to eq(5)
    expect(owner.library_items.find_by(item: TvShow.find_by(title: 'Review visibility unset')).is_public).to be_nil
  end

  it 'keeps media-page tracking personal and rejects nonowner pass mutations' do
    show, library = start_watch('Shared summary', visibility: false)
    pass = library.consumption_passes.sole
    get tv_show_path(show)
    expect(response.body).not_to include('Private review sentinel', 'Private episode sentinel', 'consumption-pass-panel')
    patch dismiss_consumption_pass_path(pass)
    expect(response).to redirect_to(login_path)
    sign_in(visitor)
    get tv_show_path(show)
    expect(response.body).not_to include('Private review sentinel', 'Private episode sentinel', 'consumption-pass-panel')
    patch dismiss_consumption_pass_path(pass)
    expect(response).to have_http_status(:not_found)
    patch resume_consumption_pass_path(pass)
    expect(response).to have_http_status(:not_found)
    post consumption_passes_path(library_item_id: library.id)
    expect(response).to have_http_status(:not_found)
    expect(pass.reload).to be_active
    expect(pass.entries.count).to eq(1)
    delete logout_path
    sign_in(owner)
    get handle_profile_path(owner.username), params: { tab: 'progress' }
    expect(Nokogiri::HTML(response.body).css('.in-progress-log-form').size).to eq(1)
    get tv_show_path(show)
    expect(response.body).to include('consumption-pass-panel', 'Manage tracking')
  end
end
