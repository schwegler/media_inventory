# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'View transition navigation', type: :system do
  before do
    page.driver.browser.navigate.to('about:blank')
    page.driver.browser.logs.get(:browser)
  end

  after do
    errors = page.driver.browser.logs.get(:browser).select { |entry| entry.level == 'SEVERE' }
    expect(errors.map(&:message)).to be_empty
  ensure
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia', features: [])
  end

  def watch_transitions
    page.execute_script(<<~JS)
      window.transitionDocument = true;
      document.documentElement.dataset.transitionFinished = '0';
      window.originalStartViewTransition ||= document.startViewTransition.bind(document);
      document.startViewTransition = (...args) => {
        const transition = window.originalStartViewTransition(...args);
        transition.finished.then(() => {
          document.documentElement.dataset.transitionFinished = String(Number(document.documentElement.dataset.transitionFinished) + 1);
        });
        return transition;
      };
    JS
  end

  def turbo_visit(item)
    page.execute_script('window.Turbo.visit(arguments[0])', movie_path(item))
    expect(page).to have_css('h1', text: item.title)
    expect(page).to have_current_path(movie_path(item))
    expect(page.evaluate_script('window.transitionDocument')).to be true
  end

  it 'can leave the app for a same-origin document without a transition opt-in' do
    [1440, 768, 390].each do |width|
      resize_browser_viewport(width, 900)
      visit root_path
      expect(page).to have_css('h1')
      page.execute_script("window.location.assign('/robots.txt')")
      expect(page).to have_current_path('/robots.txt')
      expect(page).to have_text('User-agent')
    end
  end

  it 'keeps Turbo transitions and completes repeated and superseded visits across viewport sizes' do
    first, second, final = %w[First Second Final].map { |title| Movie.create!(title: "Transition #{title}") }
    visit movie_path(first)
    watch_transitions
    [1440, 768, 390].each_with_index do |width, index|
      resize_browser_viewport(width, 900)
      turbo_visit(second)
      expect(page).to have_css("html[data-transition-finished='#{(index * 2) + 1}']")
      page.execute_script('window.Turbo.visit(arguments[0]); window.Turbo.visit(arguments[1])',
                          movie_path(first), movie_path(final))
      expect(page).to have_css('h1', text: final.title)
      expect(page).to have_current_path(movie_path(final))
      expect(page).to have_css("html[data-transition-finished='#{(index * 2) + 2}']")
      expect(page.evaluate_script('window.transitionDocument')).to be true
      expect(page.evaluate_script('document.documentElement.scrollWidth <= innerWidth')).to be true
      capture_ui_screenshot("view-transition-#{width}")
    end
  end

  it 'navigates without animation when reduced motion is requested' do
    first, second = %w[First Second].map { |title| Movie.create!(title: "Reduced motion #{title}") }
    page.driver.browser.execute_cdp('Emulation.setEmulatedMedia',
                                    features: [{ name: 'prefers-reduced-motion', value: 'reduce' }])
    visit movie_path(first)
    watch_transitions
    expect(page.evaluate_script("matchMedia('(prefers-reduced-motion: reduce)').matches")).to be true
    turbo_visit(second)
    expect(page).to have_css("html[data-transition-finished='0']")
  end

  it 'navigates when the View Transition API is unavailable' do
    first, second = %w[First Second].map { |title| Movie.create!(title: "Unsupported transition #{title}") }
    visit movie_path(first)
    page.execute_script('window.transitionDocument = true; document.startViewTransition = undefined')
    turbo_visit(second)
  end
end
