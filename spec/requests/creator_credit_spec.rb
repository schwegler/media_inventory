# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Approved creator signature', type: :request do
  it 'renders an accessible project credit with both PNG treatments on the public page' do
    get root_path

    expect(response).to have_http_status(:ok)
    document = Nokogiri::HTML(response.body)
    credit = document.at_css('footer a.creator-credit')
    expect(credit['href']).to eq('https://schweg.xyz/')
    expect(credit['aria-label']).to eq('A schweg.xyz project')
    expect(credit.css('span').map(&:text)).to eq(%w[a project])
    expect(credit.css('img').length).to eq(2)
    %w[ink light].each do |treatment|
      image = credit.at_css("img.creator-signature-#{treatment}")
      expect(image['src']).to include("schweg-signature-#{treatment}")
      expect(image['alt']).to eq('schweg.xyz')
      expect(image['width']).to eq('132')
      expect(image['height']).to eq('39')
    end
  end
end
