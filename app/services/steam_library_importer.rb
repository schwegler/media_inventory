# frozen_string_literal: true

# Store catalog access and authenticated public-library reads are independent.
class SteamLibraryImporter
  class Unavailable < StandardError; end

  def self.call(user, steam_id)
    new(user, steam_id).call
  end

  def initialize(user, steam_id)
    @user = user
    @steam_id = steam_id
    @state = SteamLibrarySync.find_or_initialize_by(user: user)
  end

  def call
    return 'cooldown' if @state.attempted_at && @state.attempted_at > 5.minutes.ago

    @state.update!(steam_id: @steam_id, attempted_at: Time.current, state: 'syncing', failure_reason: nil)
    rows = owned_games
    counts = { discovered: rows.size, imported: 0, updated: 0 }
    @user.with_lock do
      rows.each { |row| reconcile(row, counts) }
      @state.update!(**counts, state: 'ready', succeeded_at: Time.current)
    end
    'ready'
  rescue Unavailable, GameProviders::Base::Unavailable, MediaSources::Http::Error, JSON::ParserError, Timeout::Error,
         SocketError, OpenSSL::SSL::SSLError => e
    @state.update!(state: 'failed', failure_reason: e.class.name) if @state.persisted?
    'failed'
  end

  private

  def owned_games
    data = GameProviders::SteamWebApi.new(fresh: true).owned_games(@steam_id)
    valid = data.is_a?(Hash) && data['games'].is_a?(Array) &&
            data['game_count'] == data['games'].size && data['games'].size <= 5000
    raise Unavailable unless valid

    data['games'].each { |row| validate_row!(row) }
    data['games']
  end

  def validate_row!(row)
    valid = row.is_a?(Hash) && row['appid'].to_s.match?(/\A\d+\z/) && row['name'].present? &&
            row['playtime_forever'].is_a?(Integer) && row['playtime_forever'] >= 0
    raise Unavailable unless valid
  end

  def reconcile(row, counts)
    app_id = row['appid'].to_s
    library = @user.library_items.find_or_create_by!(item: canonical_game(row, app_id))
    copy = library.game_copies.find_or_initialize_by(steam_app_id: app_id)
    if copy.new_record?
      copy.assign_attributes(platform: 'PC (unspecified)', storefront: 'Steam',
                             ownership_status: 'owned', access_method: 'digital')
      counts[:imported] += 1
    else
      counts[:updated] += 1
    end
    copy.update!(imported_playtime_minutes: row['playtime_forever'])
  end

  def canonical_game(row, app_id)
    identity = GameExternalId.find_by(provider: 'steam', external_id: app_id)
    existing = identity&.video_game || VideoGame.find_by(api_id: "steam_#{app_id}") || VideoGame.find_by(api_id: app_id)
    return existing if existing

    # Bulk import deliberately avoids synchronous per-game provider enrichment.
    VideoGame.create!(title: row['name'], game_type: 'unknown').tap do |created|
      created.update_columns(api_id: "steam_#{app_id}")
      created.game_external_ids.create!(provider: 'steam', external_id: app_id)
    end
  end
end
