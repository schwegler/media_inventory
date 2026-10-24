# frozen_string_literal: true

module Editorial
  class PostImport
    class Invalid < StandardError; end

    def self.plain_text(value, limit)
      return '' unless value.is_a?(String)

      fragment = Nokogiri::HTML.fragment(value)
      fragment.css('script, style, iframe, object').remove
      fragment.text.squish.truncate(limit)
    end

    def call(post)
      raise Invalid, 'Invalid post ID' unless post.is_a?(Hash) && post['id'].is_a?(Integer) && post['id'].positive?

      article = EditorialArticle.find_or_initialize_by(wordpress_id: post['id'])
      if hidden?(post)
        suppress(article) if article.persisted?
        return
      end
      attributes = attributes_for(post)

      items = linked_titles(post.dig('content', 'rendered'))
      article.with_lock do
        if article.persisted? && article.source_modified_at > attributes[:source_modified_at]
          article.update!(checked_at: Time.current)
          return article
        end

        article.update!(attributes.merge(published: true, checked_at: Time.current))
        article.editorial_article_titles.delete_all
        items.each { |item| article.editorial_article_titles.create!(item: item) }
      end
      article
    rescue TypeError, NoMethodError
      raise Invalid, 'Malformed post metadata'
    end

    def suppress(article)
      article.with_lock do
        article.update!(published: false, checked_at: Time.current)
        article.editorial_article_titles.delete_all
      end
    end

    private

    def hidden?(post)
      (post['status'].is_a?(String) && post['status'] != 'publish') ||
        post.dig('content', 'protected') == true || post.dig('excerpt', 'protected') == true ||
        (post['password'].is_a?(String) && post['password'].present?)
    end

    def attributes_for(post)
      unless post['status'] == 'publish' && post.dig('content', 'protected') == false &&
             post.dig('excerpt', 'protected') == false && post.dig('content', 'rendered').is_a?(String)
        raise Invalid, 'Missing publication metadata'
      end

      title = self.class.plain_text(post.dig('title', 'rendered'), 300)
      canonical_url = Urls.article(post['link'])
      raise Invalid, 'Invalid title or canonical URL' if title.blank? || canonical_url.nil?

      { title: title, canonical_url: canonical_url, excerpt: self.class.plain_text(post.dig('excerpt', 'rendered'), 600),
        published_at: timestamp(post['date_gmt']), source_modified_at: timestamp(post['modified_gmt']),
        image_url: featured_image(post) }
    end

    def timestamp(value)
      unless value.is_a?(String) && value.match?(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\z/)
        raise Invalid,
              'Invalid GMT timestamp'
      end

      Time.iso8601("#{value}Z")
    rescue ArgumentError
      raise Invalid, 'Invalid GMT timestamp'
    end

    def featured_image(post)
      embedded = post['_embedded']
      media = embedded.is_a?(Hash) ? embedded['wp:featuredmedia'] : nil
      image = media.is_a?(Array) ? media.first : nil
      Urls.image(image['source_url']) if image.is_a?(Hash)
    end

    def linked_titles(content)
      Nokogiri::HTML.fragment(content).css('a[href]').filter_map { |link| Urls.title(link['href']) }.uniq
    end
  end
end
