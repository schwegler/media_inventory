# frozen_string_literal: true

module SeasonalHelper
  SEASON_CONFIG = JSON.parse(Rails.root.join('config/seasonal.json').read).freeze

  def active_season(now: Time.current)
    SEASON_CONFIG.fetch('seasons').find do |season|
      next false if SEASON_CONFIG['activeSeason'] && season['id'] != SEASON_CONFIG['activeSeason']
      next false unless season['enabled'] && season['asset'].present?

      window = season['window']
      !window || (now >= season_boundary(window.fetch('from')) && now < season_boundary(window.fetch('until')))
    end
  end

  def season_boundary(value)
    Time.iso8601(value.length == 10 ? "#{value}T00:00:00Z" : value)
  end
end
