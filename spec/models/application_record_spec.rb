# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationRecord, type: :model do
  describe 'inheritance' do
    it 'inherits from ActiveRecord::Base' do
      expect(ApplicationRecord.ancestors).to include(ActiveRecord::Base)
    end
  end

  describe 'abstract class' do
    it 'is an abstract class' do
      expect(ApplicationRecord.abstract_class).to be true
    end
  end
end
