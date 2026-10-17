# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalog and collection consistency', type: :system do
  it 'keeps mobile sort labels readable and long collection titles available without hover' do
    user = create_and_login_user
    title = 'A very long album title with an unabridged subtitle for a shared public collection'
    album = Album.create!(title: title, artist: 'A creator')
    LibraryItem.create!(user: user, item: album, is_collected: true)
    [390, 1440].each do |width|
      page.current_window.resize_to(width, 900)
      visit movies_path
      expect(page).to have_select('Sort by', selected: 'Recent Activity')
      if width == 390
        expect(page).to have_text('Scroll for more catalogs')
        expect(page.evaluate_script("document.querySelector('#sort').getBoundingClientRect().width")).to be > 250
      end
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
      capture_ui_screenshot("catalog-#{width}")
      visit collection_path(user)
      expect(page).to have_css('.shared-collection .catalog-grid')
      expect(page).to have_link(title)
      clipping = page.evaluate_script(<<~JS)
        (() => { const el = document.querySelector('.shared-collection .card-2026-title a');
          return el.scrollHeight > el.clientHeight + 1 || el.scrollWidth > el.clientWidth + 1 })()
      JS
      expect(clipping).to be false
      capture_ui_screenshot("collection-#{width}")
      expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
    end
  end
end
