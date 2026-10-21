# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Profile tracking card surfaces', type: :system do
  def dense_library(user)
    13.times do |index|
      comic = index.odd?
      title = "#{format('%02d', index)} · A long-running anthology of wonderfully complicated adventures"
      series = (comic ? Comic : TvShow).create!(title: title)
      library = user.library_items.create!(item: series, is_public: true)
      series.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                                filename: 'cover.png')
      detail = 'Interlude: The mysterious return of the extraordinarily-long-unbroken-title'
      entries = 3.times.map do |number|
        if comic
          series.comic_issues.create!(issue_number: number + 1, title: detail, release_date: Date.yesterday)
        else
          series.tv_episodes.create!(season: 12, episode: number + 1, name: detail, air_date: Date.yesterday)
        end
      end
      user.library_items.create!(item: entries.first, consumed: true)
      library.consumption_passes.first.entries.update_all(consumed_at: index.hours.ago)
    end
  end

  it 'separates dense cards and uses the shared pager across themes and responsive widths' do
    user = create_and_login_user
    user.update!(username: 'card_reader', reduce_effects: true)
    dense_library(user)
    %w[light dark].each do |theme|
      user.update!(theme: theme)
      [320, 768, 1440].each do |width|
        resize_browser_viewport(width, 1000)
        visit handle_profile_path(user.username, tab: 'progress', sort: 'title')
        expect(page).to have_css('.in-progress-card', count: 12)
        page.scroll_to(first('.in-progress-card'), align: :top)
        page.execute_script('window.scrollBy(0, -100)')
        capture_ui_screenshot("cards-#{ENV['CARD_BEFORE'] == '1' ? 'before' : 'after'}-#{theme}-#{width}")
        next if ENV['CARD_BEFORE'] == '1'

        geometry = page.evaluate_script(<<~JS)
          (() => {
          const card = document.querySelector('.in-progress-card');
          const style = getComputedStyle(card);
          const grid = getComputedStyle(card.parentElement);
          return ({ padding: parseFloat(style.paddingLeft), gap: parseFloat(grid.rowGap),
             surface: style.backgroundColor, canvas: getComputedStyle(document.body).backgroundColor,
             overflow: document.documentElement.scrollWidth > innerWidth,
             contained: Array.from(card.querySelectorAll('button, select, summary, h3, .in-progress-next-link'))
               .filter(e => e.getClientRects().length).every(e => {
                 const a = e.getBoundingClientRect(), b = card.getBoundingClientRect();
                 return a.left >= b.left && a.right <= b.right + 1;
               }) });
          })()
        JS
        expect(geometry['padding']).to be >= 12
        expect(geometry['gap']).to be >= 12
        expect(geometry['surface']).not_to eq(geometry['canvas'])
        expect(geometry['surface']).not_to eq('rgba(0, 0, 0, 0)')
        expect(geometry['overflow']).to be false
        expect(geometry['contained']).to be true
        expect(page).to have_css('.in-progress-rating-select', count: 12)
        expect(page).to have_css('.in-progress-next-link', count: 12)
        expect(page).to have_css('.pagination-wrapper nav.pagination')
        next_page = find('.pagination-wrapper .next a')
        next_page.send_keys(:enter)
        expect(page).to have_current_path(/page=2/)
        expect(page).to have_css('.in-progress-card', count: 1)
        expect(page).to have_select('Sort by', selected: 'Title A–Z')
        page.scroll_to(find('.pagination-wrapper'), align: :center)
        capture_ui_screenshot("pager-#{theme}-#{width}")
        find('.pagination-wrapper .prev a').click
        expect(page).to have_css('.in-progress-card', count: 12)
        expect(page).to have_current_path(/sort=title/)
      end
    end
  end
end
