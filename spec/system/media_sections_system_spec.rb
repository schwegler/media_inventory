# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Title section navigation', type: :system do
  let!(:show) do
    TvShow.create!(title: 'Section navigation fixture', network: 'Fixture network', writer: 'Fixture writer')
  end

  before do
    8.times { |i| show.tv_episodes.create!(name: "Episode #{i + 1}", season: 1, episode: i + 1) }
  end

  def expect_section(id)
    expect(page).to have_current_path(tv_show_path(show)) { |uri| uri.fragment == id }
    expect(page).to have_css('.media-section-nav a[aria-current="location"]', count: 1)
  end

  def block_section_visits
    page.execute_script(<<~JS)
      window.sectionRequests = 0;
      document.addEventListener('turbo:before-fetch-request', event => {
        if (event.detail.url.pathname !== location.pathname) return;
        window.sectionRequests++;
        event.preventDefault(); // A stalled request must never block local section navigation.
      });
      window.originalTitle = document.querySelector('.media-detail');
    JS
  end

  it 'navigates every section immediately with a slow network, including repeated clicks' do
    create_and_login_user
    visit tv_show_path(show)
    expect(page).to have_css('.media-section-nav a[aria-current]')
    capture_ui_screenshot('sections-desktop-overview')
    block_section_visits
    %w[my-library title-details media-entries community comments overview title-details title-details].each do |id|
      find(".media-section-nav a[href='##{id}']").click
      expect_section(id)
      expect(page.evaluate_script("document.getElementById('#{id}').getBoundingClientRect().top")).to be >= 90
      expect(page.evaluate_script('window.sectionRequests')).to eq(0)
      expect(page.evaluate_script('window.originalTitle === document.querySelector(".media-detail")')).to be true
    end
    top = page.evaluate_script('document.querySelector("#title-details").getBoundingClientRect().top')
    expect(top).to be_between(100, 140)
    expect(page).to have_css('.media-section-nav a[href="#title-details"][aria-current="location"]')
    capture_ui_screenshot('sections-desktop-details')
  end

  it 'supports keyboard activation, fragment history, reload and Turbo back restoration' do
    visit tv_show_path(show)
    find('.media-section-nav a[href="#title-details"]').send_keys(:enter)
    expect_section('title-details')
    find('.media-section-nav a[href="#media-entries"]').click
    expect_section('media-entries')
    page.go_back
    expect_section('title-details')
    page.go_forward
    expect_section('media-entries')
    page.refresh
    expect_section('media-entries')
    visit tv_shows_path
    page.go_back
    expect_section('media-entries')
    find('.media-section-nav a[href="#my-library"]').click
    expect_section('my-library')
    top = page.evaluate_script('document.querySelector("#my-library").getBoundingClientRect().top')
    expect(top).to be_between(100, 140)
  end

  it 'keeps horizontally scrolled links usable on mobile with reduced motion' do
    resize_browser_viewport(390, 844)
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia',
                                    features: [{ name: 'prefers-reduced-motion', value: 'reduce' }])
    visit tv_show_path(show)
    block_section_visits
    %w[comments media-entries my-library overview].each do |id|
      find(".media-section-nav a[href='##{id}']").click
      expect_section(id)
      expect(page.evaluate_script("document.getElementById('#{id}').getBoundingClientRect().top")).to be >= 90
    end
    expect(page.evaluate_script('window.sectionRequests')).to eq(0)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
    capture_ui_screenshot('sections-mobile-overview')
  ensure
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [])
  end

  it 'keeps working after a Turbo morph refresh' do
    visit tv_show_path(show)
    page.execute_script(<<~JS)
      document.addEventListener('turbo:morph', () => document.body.dataset.sectionMorphed = 'true', { once: true });
      window.Turbo.visit(location.href, { action: 'replace' });
    JS
    expect(page).to have_css('body[data-section-morphed="true"]')
    block_section_visits
    find('.media-section-nav a[href="#media-entries"]').click
    expect_section('media-entries')
    expect(page.evaluate_script('window.sectionRequests')).to eq(0)
  end

  it 'retains native links and visible sections when JavaScript is disabled' do
    page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', value: true)
    visit tv_show_path(show)
    %w[overview my-library title-details media-entries community comments].each do |id|
      expect(page).to have_css("[id='#{id}']", count: 1)
      expect(page).to have_link(href: "##{id}")
    end
    find('.media-section-nav a[href="#media-entries"]').click
    expect(page).to have_current_path(tv_show_path(show)) { |uri| uri.fragment == 'media-entries' }
    top = page.evaluate_script('document.querySelector("#media-entries").getBoundingClientRect().top')
    expect(top).to be_between(100, 140)
  ensure
    page.driver.browser.execute_cdp('Emulation.setScriptExecutionDisabled', value: false)
  end
end
