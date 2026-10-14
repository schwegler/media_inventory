# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Large child collections', type: :system do
  it 'batches connected entries and keeps search and season switching working' do
    series = TvShow.create!(title: 'Large collection')
    (1..30).each do |number|
      series.tv_episodes.create!(name: "Episode #{number}", season: number <= 20 ? 1 : 2, episode: number)
    end
    visit tv_show_path(series)
    expect(page).to have_content('20 of 20 shown')
    fill_in 'Search episodes', with: 'Episode 12'
    expect(page).to have_content('1 of 20 shown')
    fill_in 'Search episodes', with: ''
    click_button 'Season 2'
    expect(page).to have_content('10 of 10 shown')

    # Exercise the same Stimulus target lifecycle used by initial load and Turbo.
    page.execute_script(<<~JS)
      const section = document.querySelector('#media-entries');
      const controller = window.Stimulus.getControllerForElementAndIdentifier(section, 'child-collection');
      const originalFilter = controller.filter.bind(controller);
      window.childFilterCalls = 0;
      controller.filter = () => { window.childFilterCalls++; originalFilter(); };
      const panel = section.querySelector('#season-panel-2');
      const entry = panel.querySelector('[data-child-collection-target="entry"]');
      for (let i = 0; i < 50; i++) {
        const clone = entry.cloneNode(true);
        clone.removeAttribute('id');
        panel.appendChild(clone);
      }
    JS
    expect(page).to have_content('60 of 60 shown')
    expect(page.evaluate_script('window.childFilterCalls')).to eq(1)
    fill_in 'Search episodes', with: 'no such episode'
    expect(page).to have_content('0 of 60 shown')
    expect(page).to have_content('No matching episodes.')
  end
end
