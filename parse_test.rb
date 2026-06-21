# frozen_string_literal: true

require 'uri'

text = "My review of A Merry Friggin' Christmas: Better than expected. - 3.0★ https://trove.schweg.xyz/movies/203 #mediatracker"

facets = []
embed = nil

urls = URI.extract(text, %w[http https])
urls.each do |url|
  # Strip trailing punctuation if accidentally matched
  url = url.sub(/[.,;:!?]\z/, '')

  start_idx = text.index(url)
  next unless start_idx

  byte_start = text[0...start_idx].bytesize
  byte_end = byte_start + url.bytesize

  facets << {
    index: { byteStart: byte_start, byteEnd: byte_end },
    features: [{ '$type' => 'app.bsky.richtext.facet#link', 'uri' => url }]
  }

  next unless embed.nil?

  embed = {
    '$type' => 'app.bsky.embed.external',
    'external' => {
      'uri' => url,
      'title' => 'Trove Media Tracker',
      'description' => 'View this item on Trove'
    }
  }
end

text.to_enum(:scan, /(?<=^|\s)#([\p{L}\w]+)/).each do
  match = Regexp.last_match
  start_idx = match.begin(0)

  byte_start = text[0...start_idx].bytesize
  byte_end = byte_start + match[0].bytesize

  facets << {
    index: { byteStart: byte_start, byteEnd: byte_end },
    features: [{ '$type' => 'app.bsky.richtext.facet#tag', 'tag' => match[1] }]
  }
end

require 'json'
puts JSON.pretty_generate({ facets: facets, embed: embed })
