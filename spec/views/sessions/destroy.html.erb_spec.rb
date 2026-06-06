# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sessions/destroy.html.erb', type: :view do
  it 'renders the destroy placeholder' do
    render
    expect(rendered).to match(/Sessions#destroy/)
  end
end
