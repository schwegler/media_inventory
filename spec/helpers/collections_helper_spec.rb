# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionsHelper, type: :helper do
  describe 'helper inclusion' do
    it 'is included in the helper context' do
      expect(helper).to be_a(described_class)
    end
  end
end
