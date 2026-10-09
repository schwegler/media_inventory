# frozen_string_literal: true

namespace :games do
  desc 'Preview legacy provider ID mappings; APPLY=1 adds unambiguous IDs without merging games'
  task backfill: :environment do
    VideoGame.where.not(api_id: [nil, '']).find_each do |game|
      match = game.api_id.match(/\A(?:(steam|rawg)_)?(\d+)\z/)
      next unless match

      provider = match[1] || 'steam'
      ids = VideoGame.where(api_id: ["#{provider}_#{match[2]}", (match[2] if provider == 'steam')].compact).pluck(:id)
      existing = GameExternalId.find_by(provider: provider, external_id: match[2])
      conflict = ids.uniq.size > 1 || (existing && existing.video_game_id != game.id)
      puts "Game #{game.id}: #{provider}/#{match[2]} #{conflict ? 'CONFLICT (review required)' : 'eligible'}"
      next unless ENV['APPLY'] == '1' && !conflict

      GameExternalId.find_or_create_by!(provider: provider, external_id: match[2]) { |entry| entry.video_game = game }
    end
  end
end
