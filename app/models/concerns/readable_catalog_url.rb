# frozen_string_literal: true

module ReadableCatalogUrl
  extend ActiveSupport::Concern

  def to_param
    return unless id

    slug = catalog_url_title.to_s.parameterize
    year = release_year.to_s if respond_to?(:release_year)
    slug = [slug, year].compact_blank.join('-') if year.present? && !slug.end_with?("-#{year}")
    [id, slug.presence].compact.join('-')
  end

  def catalog_url_title
    title
  end
end
