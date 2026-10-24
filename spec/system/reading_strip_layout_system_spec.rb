# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Reading strip visual layout', type: :system do
  it 'keeps real-length story text readable at narrow, mobile and desktop widths' do
    create_and_login_user
    description = 'Inspired by the adventures of Arsène Lupin, gentleman thief Assane Diop sets out to avenge his father ' \
                  'for an injustice inflicted by a wealthy family.'
    show = TvShow.create!(title: 'Lupin', release_year: 2021, network: 'Netflix', director: 'Ludovic Bernard',
                          writer: 'George Kay, François Uzan', actors: 'Omar Sy', genre: 'Drama, Adventure, Crime',
                          metadata_credits_data: [{ 'role' => 'Creator', 'name' => 'George Kay' },
                                                  { 'role' => 'Creator', 'name' => 'François Uzan' },
                                                  { 'role' => 'Second unit director', 'name' => 'Ludovic Bernard' }],
                          metadata_details: { 'Runtime' => '46', 'language' => 'French', 'status' => 'Running',
                                              'description' => description })
    cover = ENV['READING_QA_COVER'] || Rails.root.join('spec/fixtures/files/valid-cover.png')
    show.cover_image.attach(io: File.open(cover), filename: 'lupin-cover.png', content_type: 'image/png')
    25.times do |index|
      show.tv_episodes.create!(name: "Chapter #{index + 1}", season: (index / 5) + 1, episode: (index % 5) + 1,
                               air_date: Date.new(2021, 1, 8))
    end
    excerpt = 'Newlyweds clocks in at 8:30/7:30c, Lupin’s new batch arrives, and The Invite turns dinner into a ' \
              'relationship exercise. Facet’s Friday watchlist.'
    article = EditorialArticle.create!(wordpress_id: 700,
                                       title: 'what to watch tonight: the dinner party has follow-up questions',
                                       excerpt: excerpt,
                                       canonical_url: 'https://tacobout.online/2026/10/23/what-to-watch-tonight-october-23-2026/',
                                       published_at: Time.utc(2026, 10, 23), source_modified_at: Time.current,
                                       checked_at: Time.current,
                                       image_url: 'https://tacobout.online/wp-content/uploads/2026/10/the-invite-hbo-max-official.jpg')
    article.editorial_article_titles.create!(item: show)
    image = ENV['READING_QA_IMAGE'] || Rails.root.join('spec/fixtures/files/valid-cover.png')
    blob = ActiveStorage::Blob.create_and_upload!(io: File.open(image), filename: 'article.png', content_type: 'image/png')
    allow(Editorial::Urls).to receive(:image).and_call_original
    local_image = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
    allow(Editorial::Urls).to receive(:image).with(article.image_url).and_return(local_image)
    phase = ENV.fetch('READING_QA_PHASE', 'after')
    [[1440, 1000], [647, 2047], [390, 844]].each do |width, height|
      resize_browser_viewport(width, height)
      visit tv_show_path(show)
      page.execute_script("document.documentElement.dataset.theme = 'dark'")
      page.execute_script("document.head.insertAdjacentHTML('beforeend', '<style>* {transition:none !important}</style>')")
      expect(page).to have_css('#from-tacobout .editorial-article-card', count: 1)
      expect(page).to have_css('#from-tacobout img')
      expect(page).to have_link(article.title, href: article.canonical_url)
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("strip-#{phase}-#{width}-overview")
      find('.media-section-nav a[href="#from-tacobout"]').click
      expect(page).to have_current_path(tv_show_path(show)) { |uri| uri.fragment == 'from-tacobout' }
      capture_ui_screenshot("strip-#{phase}-#{width}-reading")
      if phase != 'before'
        expect(page).to have_css('.media-information #title-details')
        expect(page).to have_css('.media-information .entity-credits')
        expect(page).to have_text('Second unit director')
      end
      next unless ENV['UI_QA_DIR']

      metrics = page.driver.browser.execute_cdp('Page.getLayoutMetrics')
      size = metrics['cssContentSize']
      screenshot = page.driver.browser.execute_cdp('Page.captureScreenshot',
                                                   format: 'png', captureBeyondViewport: true,
                                                   clip: { x: 0, y: 0, width: width, height: size['height'], scale: 1 })
      File.binwrite(File.join(ENV.fetch('UI_QA_DIR'), "strip-#{phase}-#{width}-full.png"),
                    Base64.decode64(screenshot['data']))
      geometry = page.evaluate_script(<<~JS)
        (() => {
          const reading = document.querySelector('#from-tacobout').getBoundingClientRect();
          const copy = document.querySelector('.editorial-article-copy').getBoundingClientRect();
          const title = document.querySelector('.editorial-article-copy h3');
          return {viewport:innerWidth,sectionWidth:reading.width,sectionHeight:reading.height,
            textWidth:copy.width,titleFont:getComputedStyle(title).fontSize,
            libraryBottom:document.querySelector('#my-library').getBoundingClientRect().bottom,readingTop:reading.top,
            detailsTop:document.querySelector('#title-details').getBoundingClientRect().top,overflow:document.documentElement.scrollWidth>innerWidth};
        })()
      JS
      File.write(File.join(ENV.fetch('UI_QA_DIR'), "strip-#{phase}-#{width}-metrics.json"), geometry.to_json)
      next unless phase != 'before'

      expect(geometry['titleFont'].to_f).to be >= 18
      expect(geometry['textWidth']).to be >= 240
      expect(geometry['readingTop']).to be >= geometry['libraryBottom']
      expect(geometry['sectionHeight']).to be < 320
    end
  end
end
