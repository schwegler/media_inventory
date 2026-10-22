# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Artwork lightbox', type: :system do
  def artwork(title, filename)
    comic = Comic.create!(title: title)
    comic.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files', filename)),
                             filename: filename, content_type: 'image/png')
    comic
  end

  def open_artwork
    expect(page).to have_css('.artwork-zoom[data-connected="true"]')
    find('.media-cover .artwork-zoom').click
    expect(page).to have_css('dialog[open][data-state="loaded"]')
  end

  it 'fits portrait and landscape art with accessible controls across themes and viewports' do
    user = create_and_login_user
    page.driver.browser.logs.get(:browser)
    portrait = artwork('Portrait cover', 'comic-portrait.png')
    landscape = artwork('Landscape artwork', 'landscape-cover.png')
    %w[light dark].each do |theme|
      user.update!(theme: theme)
      [320, 768, 1440].each do |width|
        resize_browser_viewport(width, 1000)
        [portrait, landscape].each do |item|
          visit comic_path(item)
          open_artwork
          expect(page).to have_css('button[aria-label="Close image lightbox"]:focus')
          expect(page).to have_link('Open full-size image in a new tab', href: /size=original/)
          expect(page).to have_css("dialog img[alt='#{item.title} cover']")
          expect(page.evaluate_script(<<~JS)).to be true
            (() => {
              const dialog = document.querySelector('dialog'), image = dialog.querySelector('img');
              const d = dialog.getBoundingClientRect(), i = image.getBoundingClientRect();
              return d.left >= 0 && d.right <= innerWidth && d.top >= 0 && d.bottom <= innerHeight &&
                Math.abs(i.width / i.height - image.naturalWidth / image.naturalHeight) < .02 &&
                d.width - i.width < 36 && document.documentElement.style.overflow === 'hidden' &&
                [...dialog.querySelectorAll('a,button')].every(e => e.getBoundingClientRect().height >= 44);
            })()
          JS
          capture_ui_screenshot("lightbox-#{theme}-#{width}-#{item == portrait ? 'portrait' : 'landscape'}")
          find_button('Close image lightbox').send_keys(:tab)
          expect(page).to have_css('dialog a:focus')
          page.driver.browser.switch_to.active_element.send_keys(:tab)
          expect(page).to have_css('dialog button:focus')
          find_button('Close image lightbox').send_keys(:escape)
          expect(page).to have_no_css('dialog')
          expect(page).to have_css('.artwork-zoom:focus')
          expect(page.evaluate_script('document.documentElement.style.overflow')).not_to eq('hidden')
          open_artwork
          click_button 'Close image lightbox'
          expect(page).to have_no_css('dialog')
          expect(page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }).to be_empty
        end
      end
    end
  end

  it 'handles loading and failures, backdrop dismissal and Back/Forward without stale locks' do
    item = artwork('Loading cover', 'comic-portrait.png')
    user = create_and_login_user
    %w[light dark].each do |theme|
      user.update!(theme: theme)
      [320, 768, 1440].each do |width|
        resize_browser_viewport(width, 1000)
        visit comic_path(item)
        expect(page).to have_css('.artwork-zoom[data-connected="true"]')
        page.execute_script(<<~JS)
          window.originalImageSrc = Object.getOwnPropertyDescriptor(HTMLImageElement.prototype, 'src');
          Object.defineProperty(HTMLImageElement.prototype, 'src', {
            ...window.originalImageSrc,
            set(value) {
              if (this.closest('.artwork-lightbox')) this.dataset.pendingSrc = value;
              else window.originalImageSrc.set.call(this, value);
            }
          });
        JS
        find('.media-cover .artwork-zoom').click
        expect(page).to have_css('dialog[data-state="loading"] [role="status"]', text: 'Loading artwork…')
        capture_ui_screenshot("lightbox-loading-#{theme}-#{width}")
        page.execute_script(<<~JS)
          Object.defineProperty(HTMLImageElement.prototype, 'src', window.originalImageSrc);
          const image = document.querySelector('dialog img');
          image.dispatchEvent(new Event('error'));
        JS
        expect(page).to have_css('dialog[data-state="error"]', text: 'This image couldn’t load.')
        expect(page).to have_no_css('dialog .artwork-fallback')
        expect(page).to have_link('Open full-size image in a new tab')
        capture_ui_screenshot("lightbox-error-#{theme}-#{width}")
        click_button 'Close image lightbox'
      end
    end
    visit comics_path
    visit comic_path(item)
    open_artwork
    %w[mousePressed mouseReleased].each do |type|
      page.driver.browser.execute_cdp('Input.dispatchMouseEvent', type: type, x: 2, y: 2, button: 'left', clickCount: 1)
    end
    expect(page).to have_no_css('dialog')
    open_artwork
    page.go_back
    expect(page).to have_current_path(comics_path)
    expect(page).to have_no_css('dialog')
    expect(page.evaluate_script('document.documentElement.style.overflow')).not_to eq('hidden')
    page.go_forward
    expect(page).to have_current_path(comic_path(item))
    expect(page).to have_no_css('dialog')
    open_artwork
    full_size = window_opened_by { click_link 'Open full-size image in a new tab' }
    within_window(full_size) { expect(page).to have_css('img') }
    full_size.close
    click_button 'Close image lightbox'
    page.execute_script("document.querySelector('.media-cover .artwork-zoom').href = '/missing-lightbox-image.png'")
    find('.media-cover .artwork-zoom').click
    expect(page).to have_css('dialog[data-state="error"]', text: 'This image couldn’t load.')
    expect(page).to have_no_css('dialog .artwork-fallback, dialog img:not([hidden])')
    click_button 'Close image lightbox'
    expect(page).to have_css('.artwork-zoom:focus')
    page.driver.browser.logs.get(:browser) # The deliberately missing image returns 404.
  end
end
