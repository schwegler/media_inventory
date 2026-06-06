# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sessions/new.html.erb', type: :view do
  before do
    render
  end

  it 'renders the login header' do
    expect(rendered).to match(/Log in/)
  end

  it 'renders the email input field' do
    expect(rendered).to have_selector('input[type="email"][name="session[email]"]')
  end

  it 'renders the password input field' do
    expect(rendered).to have_selector('input[type="password"][name="session[password]"]')
  end

  it 'renders the login submit button' do
    expect(rendered).to have_selector('input[type="submit"][value="Log in"]')
  end
end
