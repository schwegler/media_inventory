# frozen_string_literal: true

module ItemSharingHelper
  def canonical_item_url(item)
    "#{public_trove_origin}#{polymorphic_path(item)}"
  end

  def public_preview_image_url(candidate)
    uri = URI.parse(candidate.to_s)
    return "#{public_trove_origin}#{uri}" if uri.relative? && uri.path.start_with?('/') && !uri.host
    return uri.to_s if uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?

    "#{public_trove_origin}/favicon.svg"
  rescue URI::InvalidURIError
    "#{public_trove_origin}/favicon.svg"
  end

  def item_preview_image_url(item)
    if item.respond_to?(:cover_image) && item.cover_image.attached?
      origin = URI.parse(public_trove_origin)
      rails_blob_url(item.cover_image, host: origin.host, protocol: 'https', port: origin.port)
    elsif item.respond_to?(:thumbnail_url) && item.thumbnail_url.present?
      public_preview_image_url(item.thumbnail_url)
    elsif item.is_a?(TvEpisode)
      item_preview_image_url(item.tv_show)
    elsif item.is_a?(ComicIssue)
      item_preview_image_url(item.comic)
    else
      public_preview_image_url(nil)
    end
  end

  private

  def public_trove_origin
    configured = ENV.fetch('HOST', 'https://trove.schweg.xyz')
    configured = "https://#{configured}" unless configured.include?('://')
    uri = URI.parse(configured)
    return 'https://trove.schweg.xyz' unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?

    uri.path = ''
    uri.query = nil
    uri.fragment = nil
    uri.to_s.delete_suffix('/')
  rescue URI::InvalidURIError
    'https://trove.schweg.xyz'
  end
end
