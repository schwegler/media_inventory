# frozen_string_literal: true

# A provider edition is evidence about that edition, not a work's first publication.
class BookProviderMetadata
  def self.apple(data, format: nil)
    format ||= data['kind'] == 'ebook' || data['wrapperType'] == 'track' ? 'ebook' : 'audiobook'
    audio = format == 'audiobook'
    id = audio ? data['collectionId'] : data['trackId']
    title = audio ? data['collectionName'] : data['trackName']
    return if id.blank? || title.blank?

    edition = apple_edition(data, format, id, title)
    { title: title, author: data['artistName'], publisher: data['sellerName'],
      release_year: data['releaseDate']&.split('-')&.first,
      thumbnail_url: data['artworkUrl100']&.sub('100x100bb', '400x400bb'), api_id: "itunes_#{id}",
      external_url: edition[:source_url], book_format: format, book_edition_data: edition, is_local: false }
  end

  def self.apple_edition(data, format, id, title)
    audio = format == 'audiobook'
    { source: 'itunes', source_id: id.to_s, format: format, label: title,
      structure_kind: audio ? 'audio_segments' : 'chapters', published_on: data['releaseDate']&.slice(0, 10),
      source_url: audio ? data['collectionViewUrl'] : data['trackViewUrl'] }.compact
  end

  def self.attach(book, data)
    attributes = data[:book_edition_data]&.with_indifferent_access
    return unless attributes && attributes[:source_id].present?

    identity = "#{attributes[:source]}:#{attributes[:source_id]}:#{attributes[:format]}"
    book.book_editions.find_or_create_by!(identity_key: identity) do |edition|
      edition.assign_attributes(attributes.slice(:source, :source_id, :format, :label, :published_on,
                                                 :source_url, :isbn, :structure_kind))
    end
  end
end
