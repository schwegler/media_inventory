# frozen_string_literal: true

require 'active_support/all'

def filter_unique_results(all_results)
  seen = {}
  all_results.select do |item|
    key = "#{item[:title].to_s.downcase.strip}_#{item[:release_year]}"
    if seen[key]
      false
    else
      seen[key] = true
    end
  end
end

puts filter_unique_results([
                             { title: 'The Matrix', release_year: '1999', api_id: '1' },
                             { title: 'The Matrix', release_year: '1999', api_id: '2' },
                             { title: 'The Matrix', release_year: '2003', api_id: '3' }
                           ]).inspect
