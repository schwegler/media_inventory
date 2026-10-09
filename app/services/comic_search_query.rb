# frozen_string_literal: true

# A trailing year identifies a series run, rather than part of its name.
class ComicSearchQuery
  attr_reader :title, :year

  def initialize(query)
    @title = query.to_s.strip
    match = @title.match(/\s+\(?(\d{4})\)?\z/)
    return unless match && match[1].to_i.between?(1900, 2099)
    return if !match[0].include?('(') && match[1].to_i > Time.current.year + 1

    @year = match[1]
    @title = @title[0...match.begin(0)].strip
  end

  def rank(results)
    results = results.select { |result| result[:release_year].to_s == year } if year
    results.sort_by do |result|
      exact_title = normalize(result[:title]) == normalize(title)
      [exact_title ? 0 : 1, result[:source] == 'ComicVine' || result[:is_local] ? 0 : 1,
       -result[:release_year].to_i]
    end
  end

  private

  def normalize(value)
    value.to_s.downcase.sub(/\s*\(\d{4}\)\z/, '').sub(/\Athe\s+/, '').gsub(/[^[:alnum:]]/, '')
  end
end
