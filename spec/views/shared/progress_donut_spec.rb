# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_progress_donut.html.erb', type: :view do
  it 'renders progressbar with correct WAI-ARIA attributes and percentage' do
    render partial: 'shared/progress_donut', locals: { total: 10, completed: 5 }

    expect(rendered).to have_css('.progress-donut[role="progressbar"]')
    expect(rendered).to have_css('.progress-donut[aria-valuenow="50"]')
    expect(rendered).to have_css('.progress-donut[aria-valuemin="0"]')
    expect(rendered).to have_css('.progress-donut[aria-valuemax="100"]')
    expect(rendered).to have_css('.progress-donut[aria-label="Completion progress: 50% (5 of 10 completed)"]')
    expect(rendered).to have_content('50%')
    expect(rendered).to have_content('Complete')
  end

  it 'handles 0 total items without division by zero errors' do
    render partial: 'shared/progress_donut', locals: { total: 0, completed: 0 }

    expect(rendered).to have_css('.progress-donut[role="progressbar"]')
    expect(rendered).to have_css('.progress-donut[aria-valuenow="0"]')
    expect(rendered).to have_css('.progress-donut[aria-label="Completion progress: 0% (0 of 0 completed)"]')
  end
end
