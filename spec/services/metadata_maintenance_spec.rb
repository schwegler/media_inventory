# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MetadataMaintenance do
  describe '.backfill' do
    let!(:movie) { Movie.create!(title: 'Alien', director: 'Ridley Scott') }
    let!(:book) { Book.create!(title: 'Dune', author: 'Frank Herbert') }

    it 'is idempotent and backfills metadata credits for legacy records' do
      expect { MetadataMaintenance.backfill }.not_to raise_error
      expect(movie.metadata_entities.pluck(:name)).to include('Ridley Scott')
      expect(book.metadata_entities.pluck(:name)).to include('Frank Herbert')

      # Re-running backfill should not create duplicate credits
      expect { MetadataMaintenance.backfill }.not_to change(MetadataCredit, :count)
    end
  end
end
