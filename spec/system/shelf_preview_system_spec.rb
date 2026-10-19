# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Deliberate shelf sharing', type: :system do
  it 'keeps browsing read-only, publishes explicitly, and restores keyboard focus on mobile' do
    user = create_and_login_user
    user.update!(username: 'preview_owner')
    page.current_window.resize_to(390, 844)
    visit shelf_path(user.username, category: 'Movie')
    expect(page).to have_css('[data-favorite-shelf-owner-value="true"][data-connected="true"]')
    expect(user.shelf_previews.count).to eq(0)
    alpha = page.evaluate_script(<<~JS)
      document.querySelector('.shelf-preview canvas').getContext('2d').getImageData(0,0,1,1).data[3]
    JS
    expect(alpha).to be > 0
    find('button[aria-label="Choose pick 1"]').click
    expect(page).to have_css('dialog[open] input:focus')
    find('dialog input').send_keys(:escape)
    expect(page).to have_no_css('dialog[open]')
    expect(page.evaluate_script('document.activeElement.getAttribute("aria-label")')).to eq('Choose pick 1')
    click_button 'Publish share preview'
    expect(page).to have_text('Share preview published.')
    expect(user.shelf_previews.count).to eq(1)
    click_button 'Publish share preview'
    expect(page).to have_text('Share preview published.')
    expect(user.shelf_previews.count).to eq(1)
    expect(page.evaluate_script('document.documentElement.scrollWidth <= window.innerWidth')).to be true
  end
end
