# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comic cover layout', type: :system do
  it 'preserves complete portrait artwork and readable placeholders at desktop and mobile sizes' do
    comic = Comic.create!(title: 'Synthetic portrait review')
    issue = comic.comic_issues.create!(issue_number: 1, title: 'Complete cover')
    issue.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                             filename: 'comic-portrait.png', content_type: 'image/png')
    [1440, 390].each do |width|
      resize_browser_viewport(width, 1000)
      visit comic_issue_path(issue)
      expect(page).to have_css('.media-cover img')
      Selenium::WebDriver::Wait.new(timeout: 10).until do
        page.evaluate_script("document.querySelector('.media-cover img').complete")
      end
      expect(page.evaluate_script(<<~JS)).to be true
        (() => {
          const cover = document.querySelector('.media-cover');
          const image = cover.querySelector('img');
          const rect = image.getBoundingClientRect();
          return image.complete && image.naturalHeight > image.naturalWidth &&
            Math.abs(rect.width / rect.height - image.naturalWidth / image.naturalHeight) < .02 &&
            getComputedStyle(image).objectFit === 'contain' &&
            rect.bottom <= cover.getBoundingClientRect().bottom + 1 &&
            document.documentElement.scrollWidth <= innerWidth;
        })()
      JS
      capture_ui_screenshot("comic-cover-#{width}")
    end
    issue.cover_image.purge
    visit comic_issue_path(issue)
    expect(page).to have_css('.media-cover .artwork-fallback', text: 'No cover yet')
    expect(page.evaluate_script("document.querySelector('.media-cover').getBoundingClientRect().height")).to be > 100
    capture_ui_screenshot('comic-cover-placeholder-mobile')
  end
  it 'keeps albums square and comic series covers complete' do
    album = Album.create!(title: 'Synthetic square review', artist: 'Layout fixture')
    comic = Comic.create!(title: 'Synthetic series review')
    [album, comic].each do |item|
      item.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files/comic-portrait.png')),
                              filename: 'comic-portrait.png', content_type: 'image/png')
      visit polymorphic_path(item)
      expect(page).to have_css('.media-cover img')
      Selenium::WebDriver::Wait.new(timeout: 10).until do
        page.evaluate_script("document.querySelector('.media-cover img').complete")
      end
      ratio = page.evaluate_script(<<~JS)
        (() => {
          const rect = document.querySelector('.media-cover').getBoundingClientRect();
          return rect.width / rect.height;
        })()
      JS
      expect(ratio).to be_within(0.02).of(item.is_a?(Album) ? 1 : 600.0 / 920)
    end
  end
end
