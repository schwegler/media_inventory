# frozen_string_literal: true

namespace :editorial do
  desc 'Cache public WordPress posts (bounded; preserve returned window when resuming)'
  task sync: :environment do
    result = Editorial::Sync.new.call(page: ENV.fetch('PAGE', '1'), max_pages: ENV.fetch('MAX_PAGES', '2'),
                                      per_page: ENV.fetch('PER_PAGE', '25'), after: ENV.fetch('AFTER', nil),
                                      before: ENV.fetch('BEFORE', Time.current.utc.iso8601))
    puts JSON.pretty_generate(result)
    abort 'Invalid posts: watermark withheld; repair and replay this window' if result[:invalid_ids].any?
  end

  desc 'Recheck a bounded rotation of cached WordPress IDs for removal and unpublishing'
  task recheck: :environment do
    result = Editorial::Sync.new.recheck(limit: ENV.fetch('LIMIT', '25'))
    puts JSON.pretty_generate(result)
    abort 'Some rechecks failed; cached articles preserved' if result.values_at(:unavailable_ids, :invalid_ids).any?(&:any?)
  end
end
