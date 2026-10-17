# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Metadata status feedback', type: :system do
  it 'continues small status checks after the redirect and updates the page once on completion' do
    create_and_login_user
    show = TvShow.create!(title: 'Status check series')
    show.update_columns(api_id: '42')
    allow_any_instance_of(MetadataRefresher).to receive(:enqueue) do
      MetadataRefresh.find_by!(item: show).update!(state: 'refreshing', requested_at: Time.current)
      'refreshing'
    end
    visit tv_show_path(show)
    find('#metadata-health > summary').click
    click_button 'Refresh metadata'
    expect(page).to have_css('#metadata-health[data-refresh-result="true"][data-refresh-state="refreshing"]')
    expect(page).to have_text('Refreshing metadata')
    MetadataRefresh.find_by!(item: show).update!(state: 'success', succeeded_at: Time.current)
    expect(page).to have_css('#metadata-health[data-refresh-state="success"][data-refresh-result="false"]', wait: 10)
    expect(page).to have_text('Metadata refreshed. Your library history and reviews are preserved.')
  end
end
