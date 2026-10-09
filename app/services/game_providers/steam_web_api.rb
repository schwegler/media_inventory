# frozen_string_literal: true

module GameProviders
  # Operator-key reads of explicitly authorized public libraries, not account authentication.
  class SteamWebApi < Base
    def name
      'SteamWebAPI'
    end

    def capabilities
      %i[owned_games aggregate_playtime].freeze
    end

    def enabled?
      super && token.present?
    end

    def owned_games(steam_id)
      raise Unavailable unless steam_id.to_s.match?(/\A\d{17}\z/)

      json('https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/',
           key: token, steamid: steam_id, include_appinfo: 1, include_played_free_games: 1, format: 'json')['response']
    end

    private

    def cache_response?
      false
    end

    def token
      MediaSources::Registry.token(name, 'VideoGame')
    end
  end
end
