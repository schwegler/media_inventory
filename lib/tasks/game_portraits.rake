# frozen_string_literal: true

namespace :games do
  desc 'Prefer portrait provider covers for existing Steam games, preserving uploaded artwork'
  task portrait_covers: :environment do
    counts = Hash.new(0)
    VideoGame.with_attached_cover_image.find_each do |game|
      counts[GamePortraitCoverUpgrade.call(game)] += 1
    end
    puts counts.map { |state, count| "#{state}: #{count}" }.join(', ')
  end
end
