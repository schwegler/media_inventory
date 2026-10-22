# frozen_string_literal: true

# Large daily shows exceed the normal JSON body limit. Split only that response
# into TVMaze's season resources, retaining the same transport limits and cache.
class TvmazeEpisodeList
  MAX_SEASONS = 200
  MAX_EPISODES = 20_000
  SEASON_FETCH_SECONDS = 30

  attr_reader :partial

  def initialize(id, deadline: nil, revalidate: false)
    raise ArgumentError, 'Invalid TVMaze identity' unless id.to_s.match?(/\A\d+\z/)

    @id = id
    @deadline = deadline
    @revalidate = revalidate
    @partial = false
  end

  def call
    array("shows/#{@id}/episodes", revalidate: @revalidate)
  rescue MediaSources::Http::Error => e
    raise unless e.message == 'Response too large'

    seasonal_episodes
  end

  private

  def array(path, revalidate:)
    body = MediaSources::Http.cached_get("https://api.tvmaze.com/#{path}",
                                         deadline: @deadline, revalidate: revalidate)
    rows = JSON.parse(body)
    raise JSON::ParserError, 'Expected a provider list' unless rows.is_a?(Array)

    rows
  end

  def seasonal_episodes
    @deadline ||= Process.clock_gettime(Process::CLOCK_MONOTONIC) + SEASON_FETCH_SECONDS
    seasons = season_index
    rows = []
    seasons.each_with_index do |season, index|
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= @deadline
        @partial = true
        break
      end
      # Revalidate new/open seasons; ended seasons reuse bounded cached
      # bodies. A retry can progress beyond a previous rate limit without
      # spending its entire request budget on seasons it already downloaded.
      break unless append_season(rows, season, index, more: index < seasons.size - 1)
    rescue MediaSources::Http::Error, JSON::ParserError, Timeout::Error, SocketError => e
      @partial = true
      break if e.is_a?(Timeout::Error) || e.is_a?(SocketError) ||
               ['HTTP 429', 'Request deadline exceeded'].include?(e.message)
    end
    rows
  end

  def season_index
    seasons = array("shows/#{@id}/seasons", revalidate: @revalidate)
    valid = seasons.select do |season|
      season.is_a?(Hash) && season['id'].is_a?(Integer) && season['id'].positive? && season['number'].is_a?(Integer)
    end
    valid.sort_by! { |season| -season['number'] }
    @partial = valid.empty? || valid.size != seasons.size || valid.size > MAX_SEASONS
    valid.first(MAX_SEASONS)
  end

  def append_season(rows, season, index, more:)
    additions = array("seasons/#{season['id']}/episodes", revalidate: revalidate_season?(season, index))
    additions = additions.select { |row| regular_episode?(row) }
    remaining = MAX_EPISODES - rows.size
    rows.concat(additions.first(remaining))
    complete = additions.size <= remaining && (rows.size < MAX_EPISODES || !more)
    @partial = true unless complete
    complete
  end

  def revalidate_season?(season, index)
    @revalidate && (index.zero? || season['endDate'].blank? || season['endDate'].to_s >= Date.current.iso8601)
  end

  def regular_episode?(row)
    row.is_a?(Hash) && row['number'].is_a?(Integer) && !row['type'].to_s.end_with?('_special')
  end
end
