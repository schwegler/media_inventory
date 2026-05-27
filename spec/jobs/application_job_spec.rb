# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob, type: :job do
  describe 'ActiveJob behavior' do
    it 'inherits from ActiveJob::Base' do
      expect(described_class.ancestors).to include(ActiveJob::Base)
    end

    it 'can be instantiated' do
      expect(described_class.new).to be_an(ActiveJob::Base)
    end
  end
end
