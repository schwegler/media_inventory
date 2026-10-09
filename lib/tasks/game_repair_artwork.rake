# frozen_string_literal: true

namespace :games do
  desc 'Queue failed/stuck game covers; capped at 50 per invocation, preserves manual covers'
  task repair_artwork: :environment do
    ids = CoverImport.where(item_type: 'VideoGame').where(state: %w[failed pending])
                     .or(CoverImport.where(item_type: 'VideoGame', state: 'processing').where('attempted_at < ?',
                                                                                              10.minutes.ago))
                     .limit(50).pluck(:item_id)
    VideoGame.where(id: ids).find_each do |game|
      ImportMediaCoverJob.perform_later(game, game.thumbnail_url) if game.thumbnail_url.present?
    end
    puts "Queued up to #{ids.size} game artwork repairs"
  end
end
