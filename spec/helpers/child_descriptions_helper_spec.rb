# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChildDescriptionsHelper, type: :helper do
  describe '#child_description' do
    it 'preserves paragraph boundaries and emphasis without nested paragraphs' do
      result = helper.child_description('<p>THE X-MEN SAIL AT DAWN!</p><p>A <strong>new</strong> beginning.</p>')
      fragment = Nokogiri::HTML.fragment(result)
      expect(fragment.css('p').map(&:text)).to eq(['THE X-MEN SAIL AT DAWN!', 'A new beginning.'])
      expect(fragment.css('strong').text).to eq('new')
    end

    it 'formats plain text paragraphs and removes unsafe attributes and elements' do
      summary = "First paragraph.\n\nSecond <em onclick='alert(1)'>paragraph</em><iframe src='unsafe'></iframe>."
      result = helper.child_description(summary)
      fragment = Nokogiri::HTML.fragment(result)
      expect(fragment.css('p').size).to eq(2)
      expect(fragment.css('iframe, [onclick]')).to be_empty
      expect(fragment.css('em').text).to eq('paragraph')
    end
  end
end
