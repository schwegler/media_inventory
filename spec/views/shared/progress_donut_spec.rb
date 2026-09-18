# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_progress_donut.html.erb', type: :view do
  it 'renders progressbar role and ARIA attributes with correct percentage' do
    render partial: 'shared/progress_donut', locals: { total: 10, completed: 7 }

    expect(rendered).to have_css('div.progress-donut[role="progressbar"]')
    expect(rendered).to have_css('div.progress-donut[aria-valuenow="70"]')
    expect(rendered).to have_css('div.progress-donut[aria-valuemin="0"]')
    expect(rendered).to have_css('div.progress-donut[aria-valuemax="100"]')
    expect(rendered).to have_css('div.progress-donut[aria-label="Completion progress"]')
    expect(rendered).to have_content('70%')
  end
end
