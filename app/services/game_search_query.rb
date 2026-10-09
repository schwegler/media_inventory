# frozen_string_literal: true

# Ranking is not identity reconciliation. Only identical provider IDs are grouped;
# same-title releases remain separate until a strong cross-provider ID is known.
class GameSearchQuery
  def initialize(query)
    @query = normalize(query)
  end

  def rank(results)
    seen = {}
    ranked = results.filter_map do |result|
      next if result[:title].blank?

      key = result[:api_id].presence || [result[:source], result[:title], result[:release_year]]
      next if seen[key]

      seen[key] = true
      type = result[:game_type].presence || inferred_type(result[:title])
      result.merge(game_type: type)
    end
    ranked.sort_by do |result|
      title = normalize(result[:title])
      [title == @query ? 0 : 1, %w[dlc soundtrack bundle].include?(result[:game_type]) ? 1 : 0,
       title.start_with?(@query) ? 0 : 1, result[:is_local] ? 0 : 1, title]
    end
  end

  private

  def normalize(title)
    title.to_s.downcase.sub(/\s*\(\d{4}\)\z/, '').gsub(/[^\p{Alnum}]+/, ' ').strip
  end

  def inferred_type(title)
    return 'soundtrack' if title.match?(/\bsoundtrack\b/i)
    return 'dlc' if title.match?(/\bDLC\b/i)

    'unknown'
  end
end
