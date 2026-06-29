# frozen_string_literal: true

require 'spec_helper'

describe ApplicationHelper do
  describe 'full_title' do
    it 'includes the page title' do
      expect(full_title('foo')).to match(/foo/)
    end

    it 'includes the base title' do
      expect(full_title('foo')).to match(/^foo \| Trove$/)
    end

    it 'does not include a bar for the home page' do
      expect(full_title('')).to match(/^Trove$/)
    end
  end

  describe 'render_stars' do
    it 'returns an empty string when rating is blank' do
      expect(render_stars(nil)).to eq('')
      expect(render_stars('')).to eq('')
    end

    it 'returns an accessible span with stars' do
      result = render_stars(3.5)
      expect(result).to have_css('span.stars-display')
      expect(result).to have_selector('span[role="img"]')
      expect(result).to have_selector('span[aria-label="Rated 3.5 out of 5 stars"]')
      expect(result).to have_selector('span[title="3.5 / 5"]')
      expect(result).to include('★★★½')
    end

    it 'handles integer ratings correctly' do
      result = render_stars(4)
      expect(result).to include('★★★★')
      expect(result).to have_selector('span[aria-label="Rated 4.0 out of 5 stars"]')
    end
  end
end
