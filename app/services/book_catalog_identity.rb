# frozen_string_literal: true

# Exact title + authors only; fuzzy search ranking never establishes identity.
class BookCatalogIdentity
  def self.existing(data, strict: true)
    return Book.find_by(id: data[:catalog_id]) if data[:is_local] && data[:catalog_id]

    book = provider_book(data)
    return book if book
    return if data[:author].blank? || data[:title].blank?

    matches = Book.where('LOWER(TRIM(title)) = ?', data[:title].to_s.strip.downcase).order(:id).select do |candidate|
      normalize(candidate.author) == normalize(data[:author])
    end
    if matches.size > 1
      return unless strict

      raise MetadataImport::Invalid,
            'Several matching works exist. Select the intended Trove catalog result.'
    end

    matches.first
  end

  def self.provider_book(data)
    book = Book.order(:id).find_by(api_id: data[:api_id]) if data[:api_id].present?
    return book if book

    if data[:book_edition_data]
      edition = BookEdition.where(source: data.dig(:book_edition_data, :source),
                                  source_id: data.dig(:book_edition_data, :source_id)).order(:id).first
      return edition.book if edition
    end
    Book.order(:id).find_by(external_url: data[:external_url]) if data[:external_url].present?
  end

  def self.normalize(value)
    value.to_s.downcase.gsub(/\band\b|&/, ',').split(',').map { |part| part.gsub(/[^[:alnum:]]/, '') }.sort
  end
end
