# frozen_string_literal: true

module Editorial
  module Urls
    TITLE_MODELS = { 'movies' => Movie, 'tv_shows' => TvShow, 'books' => Book, 'albums' => Album,
                     'video_games' => VideoGame, 'comics' => Comic,
                     'tv_episodes' => TvEpisode, 'comic_issues' => ComicIssue }.freeze

    module_function

    def secure_uri(value)
      return unless value.is_a?(String) && value.bytesize <= 2048

      uri = URI.parse(value)
      uri if uri.is_a?(URI::HTTPS) && uri.port == 443 && uri.userinfo.nil? && uri.fragment.nil?
    rescue URI::InvalidURIError
      nil
    end

    def article(value)
      uri = secure_uri(value)
      uri.to_s if uri && uri.host == 'tacobout.online' && uri.path.start_with?('/')
    end

    def image(value)
      uri = secure_uri(value)
      return unless uri

      path = if uri.host == 'tacobout.online'
               uri.path
             elsif %w[i0.wp.com i1.wp.com i2.wp.com].include?(uri.host)
               uri.path.delete_prefix('/tacobout.online') if uri.path.start_with?('/tacobout.online/')
             end
      return if path && URI::DEFAULT_PARSER.unescape(path).split('/').intersect?(%w[. ..])

      uri.to_s if path&.match?(%r{\A/wp-content/uploads/[a-zA-Z0-9_./%-]+\.(?:jpe?g|png|webp|gif)\z}i)
    end

    def title(value)
      # Match actual public routes and IDs only; never resolve editorial title text.
      uri = secure_uri(value.to_s.split('#', 2).first)
      origin = Object.new.extend(ItemSharingHelper).send(:public_trove_origin)
      return unless uri && "#{uri.scheme}://#{uri.host}" == origin && uri.query.nil?

      match = uri.path.match(%r{\A/(#{TITLE_MODELS.keys.join('|')})/([1-9]\d*)(?:-[a-z0-9-]+)?/?\z})
      TITLE_MODELS.fetch(match[1]).find_by(id: match[2]) if match
    end
  end
end
