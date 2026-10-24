# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Editorial related reading', type: :system do
  let!(:movie) { Movie.create!(title: 'The art of paying attention', release_year: 2026, director: 'A. Filmmaker') }

  before do
    2.times do |index|
      title = index.zero? ? 'When a small story leaves a lasting impression' : 'A few more things worth noticing'
      image = 'https://tacobout.online/wp-content/uploads/2026/10/fixture.png' if index.zero?
      excerpt = 'A closer look at the details that stay with us, and the stories we tell.'
      article = EditorialArticle.create!(wordpress_id: 100 + index,
                                         title: title,
                                         excerpt: excerpt,
                                         canonical_url: "https://tacobout.online/reading-#{index}/",
                                         published_at: Time.utc(2026, 10, 20 + index),
                                         source_modified_at: Time.current, checked_at: Time.current,
                                         image_url: image)
      article.editorial_article_titles.create!(item: movie)
    end
    # Substitute only the known synthetic image with a locally served asset.
    # URL validation itself is exercised by importer/request examples.
    allow(Editorial::Urls).to receive(:image).and_call_original
    allow(Editorial::Urls).to receive(:image)
      .with('https://tacobout.online/wp-content/uploads/2026/10/fixture.png')
      .and_return(ActionController::Base.helpers.asset_path('brand/trove_logo_dark_card.png'))
  end

  it 'navigates to reading cards at desktop and mobile sizes without overlap' do
    [[1440, 1000, 'desktop'], [390, 844, 'mobile']].each do |width, height, name|
      resize_browser_viewport(width, height)
      visit movie_path(movie)
      expect(page.title).to include(movie.title)
      find('.media-section-nav a[href="#from-tacobout"]').click
      expect(page).to have_css('#from-tacobout h2', text: 'from taco ’bout it')
      expect(page).to have_css('.editorial-article-card', count: 2)
      expect(page).to have_css('.editorial-article-placeholder', count: 1)
      expect(page).to have_link('When a small story leaves a lasting impression', href: 'https://tacobout.online/reading-0/')
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      columns = page.evaluate_script(<<~JS)
        getComputedStyle(document.querySelector('.editorial-article-grid')).gridTemplateColumns.split(' ').length
      JS
      expect(columns).to eq(width > 640 ? 2 : 1)
      expect(page.driver.browser.logs.get(:browser).select { |log| log.level == 'SEVERE' }).to be_empty
      capture_ui_screenshot("editorial-#{name}")
    end
  end
end
