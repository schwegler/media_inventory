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
    it 'returns empty string when rating is blank' do
      expect(render_stars(nil)).to eq('')
      expect(render_stars('')).to eq('')
    end

    it 'renders accessible span with aria-label and title for integer ratings' do
      result = render_stars(4)
      expect(result).to include('class="star-rating"')
      expect(result).to include('aria-label="4 out of 5 stars"')
      expect(result).to include('title="4 / 5 stars"')
      expect(result).to include('★★★★')
    end

    it 'renders accessible span with aria-label and title for half-star ratings' do
      result = render_stars(4.5)
      expect(result).to include('class="star-rating"')
      expect(result).to include('aria-label="4.5 out of 5 stars"')
      expect(result).to include('title="4.5 / 5 stars"')
      expect(result).to include('★★★★½')
    end
  end
end
