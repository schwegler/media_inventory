# frozen_string_literal: true

module MediaSourcesHelper
  APPLE_SOURCE_LABELS = {
    'Album' => 'View on Apple Music', 'Book' => 'View on Apple Books', 'Comic' => 'View on Apple Books',
    'VideoGame' => 'View on Apple Arcade'
  }.freeze

  def media_source_links(item)
    title = CGI.escape(item.title)
    links = []
    links << external_media_source(item) if item.external_url.present?
    links.concat(media_search_sources(item, title))
    links << media_source_link('Google Search Options', "https://www.google.com/search?q=stream+or+buy+#{title}", 'search')
    links << media_source_link('Buy on Amazon', "https://www.amazon.com/s?k=#{title}", 'shopping-bag')
    links
  end

  private

  def media_source_link(label, url, icon, kind: 'search')
    { label: label, url: url, icon: icon, kind: kind }
  end

  def external_media_source(item)
    label, icon = external_media_source_identity(item)
    media_source_link(label, item.external_url, icon, kind: 'source')
  end

  def external_media_source_identity(item)
    host = URI.parse(item.external_url).host.to_s.downcase.delete_prefix('www.')
    case host
    when 'itunes.apple.com', 'music.apple.com', 'books.apple.com', 'tv.apple.com'
      [APPLE_SOURCE_LABELS.fetch(item.class.name, 'View on Apple TV'), MediaLayoutHelper::CATALOGS.fetch(item.class.name)[2]]
    when 'openlibrary.org' then ['Borrow on Open Library', 'book']
    when 'tvmaze.com' then ['View on TVmaze', 'tv']
    when 'store.steampowered.com', 'steamcommunity.com' then ['View on Steam', 'gamepad']
    else ['View Official Source', 'globe']
    end
  rescue URI::InvalidURIError
    ['View Official Source', 'globe']
  end

  def media_search_sources(item, title)
    case item.class.name
    when 'Movie', 'TvShow'
      [media_source_link('Search JustWatch', "https://www.justwatch.com/us/search?q=#{title}", 'film')]
    when 'VideoGame'
      [media_source_link('Search HowLongToBeat', "https://howlongtobeat.com/?q=#{title}", 'gamepad')]
    when 'Comic'
      [media_source_link('Search Goodreads', "https://www.goodreads.com/search?q=#{title}", 'book'),
       media_source_link('Search Open Library', "https://openlibrary.org/search?q=#{title}", 'library')]
    else []
    end
  end
end
