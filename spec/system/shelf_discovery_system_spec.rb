# frozen_string_literal: true

require 'rails_helper'
require 'base64'

RSpec.describe 'Shelf discovery and real exports', type: :system do
  it 'renders mixed covers, downloads both formats and keeps visitor presentation read-only' do
    user = create_and_login_user
    user.update!(username: 'export_check')
    samples = [[Book, 'Portrait cover sample', 'comic-portrait.png'],
               [Album, 'Square cover sample', 'valid-cover.png'],
               [VideoGame, 'Landscape cover sample', 'landscape-cover.png'],
               [Movie, 'A very long title with punctuation, emoji 🦇 and a surprisingly elaborate subtitle', nil],
               [TvShow, 'Final selection', 'comic-portrait.png']]
    picks = samples.map do |klass, title, filename|
      item = klass.create!(title: title)
      if filename
        item.cover_image.attach(io: File.open(Rails.root.join('spec/fixtures/files', filename)),
                                filename: filename, content_type: 'image/png')
      end
      { type: klass.name, id: item.id }
    end
    collection = user.shelf_collections.create!(title: 'Winter stories & late discoveries',
                                                description: 'Five different kinds of story.', picks: picks,
                                                presentation: { theme: 'christmas', layout: 'exhibition' })
    visit shelf_path(user.username, collection: collection.slug)
    expect(page).to have_css('.favorite-shelf[data-connected="true"]')
    expect(page).to have_css('.shelf-preview canvas[width="1080"][height="1920"]')
    %w[exhibition collector mixtape].each do |layout|
      choose("#{{ 'exhibition' => 'Gallery', 'collector' => 'Feature', 'mixtape' => 'Mixtape' }.fetch(layout)} layout")
      expect(page).to have_css("canvas[data-rendered-layout='#{layout}'][aria-busy='false']", wait: 12)
      expect(find('#shelf-image-alt-text', visible: :all).value).to include("#{layout} layout")
      size = page.evaluate_script("document.querySelector('.shelf-preview canvas').toDataURL('image/png').length")
      expect(size).to be > 1000
      write_canvas("shelf-five-#{layout}-1080x1920.png", [1080, 1920])
    end
    find('input[name="shelf-format"][value="landscape"]').choose
    expect(page).to have_css('.shelf-preview canvas[width="1200"][height="630"]')
    write_canvas('shelf-five-landscape-1200x630.png', [1200, 630])
    download_dir = Dir.mktmpdir('trove-export-')
    page.driver.browser.execute_cdp('Page.setDownloadBehavior', behavior: 'allow', downloadPath: download_dir)
    click_button 'Save & download image'
    expect(page).to have_text('PNG downloaded. Ready to share.')
    Timeout.timeout(10) { sleep 0.1 until Dir[File.join(download_dir, '*.png')].any? }
    downloaded = File.binread(Dir[File.join(download_dir, '*.png')].first)
    expect(downloaded.byteslice(16, 8).unpack('NN')).to eq([1200, 630])
    click_button 'Save appearance'
    expect(page).to have_text('Appearance saved.')
    # Exercise the real renderer's failed remote-image path and long-heading fallback.
    fallback = page.evaluate_async_script(<<~JS)
      const done = arguments[0];
      import("controllers/shelf_image").then(async module => {
        const canvas = document.createElement("canvas");
        await module.renderShelfImage(canvas, {
          picks: [{ title: "An unavailable cover with a deliberately long readable caption", type: "Movie",
                    cover: "https://artwork.invalid/shelf-qa.jpg" }],
          overview: false, format: "portrait", theme: "halloween", companion: "none",
          headline: "An unusually long collection title for late-night discoveries and strange stories 🦇",
          category: "Movies", handle: "export_check"
        });
        done(canvas.toDataURL("image/png").split(",")[1]);
      }).catch(error => done({ error: error.message }));
    JS
    expect(fallback).to be_a(String)
    fallback_png = Base64.decode64(fallback)
    expect(fallback_png.byteslice(16, 8).unpack('NN')).to eq([1080, 1920])
    if ENV['UI_QA_DIR']
      File.binwrite(File.join(ENV.fetch('UI_QA_DIR'), 'shelf-failed-remote-long-heading.png'), fallback_png)
    end
    # A fresh guest view must use the saved owner presentation even with conflicting URL parameters.
    page.driver.browser.manage.delete_all_cookies
    visit shelf_path(user.username, collection: collection.slug, theme: 'electric', layout: 'reading')
    expect(page).to have_css('.favorite-shelf[data-shelf-theme="christmas"][data-shelf-layout="mixtape"]')
    expect(page).to have_no_css('.shelf-themes, .shelf-customization, .shelf-controls')
    expect(page).to have_css('.shelf-slot', count: 5)
    expect(page).to have_link('Make your own shelf')
    [1400, 768, 390].each do |width|
      resize_browser_viewport(width, 900)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be(true)
      capture_ui_screenshot("visitor-collection-#{width}")
    end
    page.execute_script("document.querySelector('.shelf-formats').scrollIntoView({block:'center'})")
    point = page.evaluate_script(<<~JS)
      (() => {
      const label = document.querySelector('input[value="landscape"]').closest('label');
      const box = label.getBoundingClientRect();
      return {x: box.x + box.width / 2, y: box.y + box.height / 2};
      })()
    JS
    page.driver.browser.execute_cdp('Input.dispatchTouchEvent', type: 'touchStart', touchPoints: [point])
    page.driver.browser.execute_cdp('Input.dispatchTouchEvent', type: 'touchEnd', touchPoints: [])
    expect(page).to have_css('.shelf-preview canvas[width="1200"][height="630"]')
  end

  def write_canvas(filename, dimensions)
    encoded = page.evaluate_script("document.querySelector('.shelf-preview canvas').toDataURL('image/png').split(',')[1]")
    png = Base64.decode64(encoded)
    expect(png.byteslice(16, 8).unpack('NN')).to eq(dimensions)
    return unless ENV['UI_QA_DIR']

    FileUtils.mkdir_p(ENV.fetch('UI_QA_DIR'))
    File.binwrite(File.join(ENV.fetch('UI_QA_DIR'), filename), png)
  end
end
