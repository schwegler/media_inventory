# frozen_string_literal: true

# Rank candidates for selection; never use this score to merge works or editions.
class BookSearchQuery
  def initialize(query)
    @query = normalize(query)
  end

  def rank(results)
    occurrences = Hash.new(0)
    results.each_with_index.sort_by do |result, index|
      title = normalize(result[:title])
      score = title == @query ? 0 : 2
      score = 1 if score == 2 && title.present? && @query.include?(title)
      # Keep both formats discoverable even when one has many same-title editions.
      key = [score, result[:book_format]]
      occurrence = occurrences[key]
      occurrences[key] += 1
      [score, occurrence, index]
    end.map(&:first)
  end

  private

  def normalize(value)
    value.to_s.downcase.gsub(/[^[:alnum:]\s]/, '').squish
  end
end
