# frozen_string_literal: true

module Editorial
  class Sync
    def initialize(client: Client.new, commit: ->(&block) { block.call })
      @client = client
      @import = PostImport.new
      @commit = commit
    end

    # Explicit resumable windows: retain the same before/after values when a run
    # reaches its page budget. Advance the watermark only after a complete window.
    def call(page: 1, max_pages: 2, per_page: 25, after: nil, before: Time.current.utc.iso8601)
      page = bounded_integer(page, 1, 1_000_000)
      max_pages = bounded_integer(max_pages, 1, 20)
      per_page = bounded_integer(per_page, 1, 50)
      window = { modified_before: Time.iso8601(before).utc.iso8601 }
      window[:modified_after] = (Time.iso8601(after) - 1.second).utc.iso8601 if after
      report = { imported: 0, invalid_ids: [], next_page: page, after: after, before: window[:modified_before] }
      max_pages.times do
        posts = @client.fetch(params: window.merge(page: page, per_page: per_page, status: 'publish',
                                                   context: 'view', orderby: 'modified', order: 'asc'))
        raise Client::Unavailable, 'Invalid or oversized post list' unless posts.is_a?(Array) && posts.size <= per_page

        posts.each { |post| import_post(post, report) }
        page += 1
        report[:next_page] = page
        next unless posts.size < per_page || page > @client.total_pages.to_i

        report[:next_page] = nil
        report[:watermark] = report[:before] if report[:invalid_ids].empty?
        break
      end
      report
    end

    # Public lists cannot reveal unpublishing. Recheck a bounded rotation of known
    # IDs, suppressing only explicit hidden responses or confirmed 404/410s.
    def recheck(limit: 25)
      report = { checked: 0, unavailable_ids: [], invalid_ids: [] }
      EditorialArticle.order(:checked_at, :id).limit(bounded_integer(limit, 1, 100)).each do |article|
        recheck_article(article, report)
      end
      report
    end

    private

    def bounded_integer(value, min, max)
      number = Integer(value)
      raise ArgumentError, "Expected #{min}..#{max}" unless number.between?(min, max)

      number
    end

    def import_post(post, report)
      @commit.call { @import.call(post) }
      report[:imported] += 1
    rescue PostImport::Invalid
      report[:invalid_ids] << (post.is_a?(Hash) ? post['id'] : nil)
    end

    def recheck_article(article, report)
      post = @client.fetch(id: article.wordpress_id, params: { context: 'view' })
      raise PostImport::Invalid, 'Unexpected post ID' unless post.is_a?(Hash) && post['id'] == article.wordpress_id

      @commit.call { @import.call(post) }
      report[:checked] += 1
    rescue Client::Removed
      @commit.call { @import.suppress(article) }
      report[:checked] += 1
    rescue Client::Unavailable
      report[:unavailable_ids] << article.wordpress_id
      @commit.call { article.update!(checked_at: Time.current) } # Rotate failures without discarding their safe cache.
    rescue PostImport::Invalid
      report[:invalid_ids] << article.wordpress_id
      @commit.call { article.update!(checked_at: Time.current) }
    end
  end
end
