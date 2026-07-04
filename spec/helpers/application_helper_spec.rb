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
    it 'returns empty string for blank rating' do
      expect(helper.render_stars(nil)).to eq('')
      expect(helper.render_stars('')).to eq('')
    end

    it 'renders full stars' do
      result = helper.render_stars(3)
      expect(result).to include('★★★')
      expect(result).to include('role="img"')
      expect(result).to include('aria-label="Rated 3.0 out of 5 stars"')
    end

    it 'renders half stars' do
      result = helper.render_stars(3.5)
      expect(result).to include('★★★½')
      expect(result).to include('aria-label="Rated 3.5 out of 5 stars"')
    end

    it 'renders correctly for strings' do
      result = helper.render_stars('4.5')
      expect(result).to include('★★★★½')
      expect(result).to include('aria-label="Rated 4.5 out of 5 stars"')
    end
  end
end
