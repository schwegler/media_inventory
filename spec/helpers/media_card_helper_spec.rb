# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaCardHelper, type: :helper do
  describe '#media_card_presentation' do
    it 'strips a trailing year from the title and surfaces it as a fact' do
      show = TvShow.new(title: 'The Gilded Age (2022)', network: 'HBO', writer: 'Julian Fellowes', release_year: 2022)
      card = helper.media_card_presentation(show)

      expect(card.title).to eq('The Gilded Age')
      expect(card.byline.value).to eq('HBO')
      expect(card.credits.map(&:label)).to eq(['Created by'])
      expect(card.facts).to eq(['2022'])
    end

    it 'uses the director as the movie byline and skips a duplicate writer credit' do
      movie = Movie.new(title: 'A Nightmare on Elm Street', director: 'Wes Craven', writer: 'Wes Craven',
                        release_year: 1984, genre: 'Horror, Thriller, Mystery')
      card = helper.media_card_presentation(movie)

      expect(card.byline.value).to eq('Wes Craven')
      expect(card.credits).to be_empty
      expect(card.facts).to eq(%w[1984 Horror Thriller])
    end

    it 'abbreviates long name lists while keeping the full value' do
      comic = Comic.new(title: 'X-Men (2024)', writer: 'Jed MacKay',
                        artist: 'J.P. Mayer, Marte Gracia, Ryan Stegman', issue_number: 1)
      card = helper.media_card_presentation(comic)

      art = card.credits.first
      expect(art.label).to eq('Art by')
      expect(art.value).to eq('J.P. Mayer, Marte Gracia +1')
      expect(art.full).to eq('J.P. Mayer, Marte Gracia, Ryan Stegman')
      expect(card.facts).to eq(['2024', '#1'])
    end
  end
end
