# frozen_string_literal: true

# Provider portraits take priority. Wikipedia is an exact-name, role-checked fallback.
class EntityPortraitLookup
  ROLE_WORDS = {
    /writer|screenwriter|author|story/i => /writer|author|novelist|poet|screenwriter/i,
    /actor|cast|guest|voice|performer/i => /actor|actress|performer|comedian/i,
    /director|creator|producer/i => /director|filmmaker|producer|creator/i,
    /artist|pencil|ink|color|letter|illustrat/i => /artist|illustrator|cartoonist|comics|comic book/i,
    /music|composer|singer|vocal|instrument/i => /musician|composer|singer|songwriter/i
  }.freeze

  def self.call(entity)
    return unless entity.kind == 'person' && entity.thumbnail_url.blank? && !entity.cover_image.attached?

    new(entity).call
  end

  def initialize(entity)
    @entity = entity
  end

  def call
    title = URI.encode_www_form_component(@entity.name.tr(' ', '_')).gsub('+', '%20')
    summary = JSON.parse(MediaSources::Http.cached_get("https://en.wikipedia.org/api/rest_v1/page/summary/#{title}"))
    return unless matching_person?(summary)

    image = summary['thumbnail'].is_a?(Hash) ? summary.dig('thumbnail', 'source') : nil
    return unless image.present? && URI(image).host == 'upload.wikimedia.org'

    MediaSources::Http.validated_uri(image)
    provenance = commons_metadata(image)
    return unless provenance

    @entity.with_lock do
      return if @entity.thumbnail_url.present? || @entity.cover_image.attached?

      @entity.update!(thumbnail_url: image, portrait_metadata: provenance)
    end
  rescue JSON::ParserError, MediaSources::Http::Error, URI::InvalidURIError, Timeout::Error,
         SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError => e
    Rails.logger.info "Portrait lookup unavailable for MetadataEntity##{@entity.id}: #{e.class}"
  end

  private

  def matching_person?(summary)
    return false unless summary.is_a?(Hash)

    names = [@entity.name, *@entity.aliases].map { |name| MetadataEntity.normalize(name) }
    return false unless summary['type'] == 'standard' && names.include?(MetadataEntity.normalize(summary['title']))

    roles = @entity.metadata_credits.distinct.pluck(:role).join(' ')
    ROLE_WORDS.any? { |role, words| roles.match?(role) && summary['description'].to_s.match?(words) }
  end

  def commons_metadata(image)
    parts = URI(image).path.split('/')
    filename = URI::DEFAULT_PARSER.unescape(parts.include?('thumb') ? parts[-2] : parts[-1])
    query = URI.encode_www_form(action: 'query', format: 'json', prop: 'imageinfo', iiprop: 'url|extmetadata',
                                titles: "File:#{filename}")
    data = JSON.parse(MediaSources::Http.cached_get("https://commons.wikimedia.org/w/api.php?#{query}"))
    pages = data.is_a?(Hash) && data['query'].is_a?(Hash) ? data['query']['pages'] : nil
    return unless pages.is_a?(Hash)

    page = pages.values.first
    return unless page.is_a?(Hash)

    info = Array(page['imageinfo']).first
    return unless info.is_a?(Hash)

    fields = info['extmetadata'] || {}
    return unless fields.is_a?(Hash)

    license = plain(fields.dig('LicenseShortName', 'value'))
    # Only accept freely reusable Commons images with explicit license and source data.
    return unless license.match?(/\A(?:CC BY(?:-SA)?(?: [\d.]+)?|CC0(?: [\d.]+)?|Public domain)\z/i)
    return unless info['descriptionurl'].to_s.start_with?('https://commons.wikimedia.org/wiki/File:')

    { 'source_url' => info['descriptionurl'], 'credit' => plain(fields.dig('Artist', 'value')).first(300),
      'license' => license, 'provider' => 'Wikimedia Commons' }
  end

  def plain(value)
    ActionController::Base.helpers.strip_tags(value.to_s).squish
  end
end
