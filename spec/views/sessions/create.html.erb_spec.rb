# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'sessions/create.html.erb', type: :view do
  it 'renders the create placeholder' do
    render
    expect(rendered).to match(/Sessions#create/)
  end
end
