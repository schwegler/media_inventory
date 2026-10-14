# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GameDescriptionsHelper, type: :helper do
  it 'separates imported store lines into paragraphs' do
    result = helper.game_description_prose("Battle royale.\nOnline features require an account.<br>1 player")
    expect(Nokogiri::HTML.fragment(result).css('p').map(&:text)).to eq(
      ['Battle royale.', 'Online features require an account.', '1 player']
    )
  end

  it 'preserves safe rich formatting and removes unsafe attributes' do
    result = helper.game_description_prose('<p>A <strong onclick="bad()">battle</strong>.</p><ul><li>Solo</li></ul>')
    fragment = Nokogiri::HTML.fragment(result)
    expect(fragment.css('strong').text).to eq('battle')
    expect(fragment.css('li').text).to eq('Solo')
    expect(fragment.css('[onclick]')).to be_empty
  end

  it 'previews the opening paragraph with separation from store boilerplate' do
    expect(helper.game_description_preview('<p>Play together.</p><p>License terms.</p>')).to eq('Play together.')
  end
end
