# frozen_string_literal: true

module Editorial
  # Network reads happen outside transactions. Every cache/checkpoint mutation is
  # fenced by a renewable lease, using conditional UPDATE on SQLite and PostgreSQL.
  class Runner
    class LostLease < StandardError; end
    LEASE = 2.minutes

    def initialize(client: Client.new)
      @sync = Sync.new(client: client, commit: method(:commit))
    end

    def call(max_pages: 2, per_page: 25, recheck_limit: 25)
      pages = bounded(max_pages, 1, 20)
      size = bounded(per_page, 1, 50)
      checks = bounded(recheck_limit, 1, 100)
      @state = EditorialSyncState.create_or_find_by!(name: 'tacobout')
      @token = SecureRandom.uuid
      return { status: 'busy' } unless acquire?

      report = {}
      begin
        report[:import] = import_pages(pages, size)
        report[:recheck] = @sync.recheck(limit: checks)
        report[:status] = 'ok'
        report
      ensure
        EditorialSyncState.where(id: @state.id, lease_token: @token).update_all(lease_token: nil, lease_until: nil)
      end
    end

    private

    def bounded(value, min, max)
      Integer(value).tap { |number| raise ArgumentError, "Expected #{min}..#{max}" unless number.between?(min, max) }
    end

    def acquire?
      EditorialSyncState.where(id: @state.id).where('lease_until IS NULL OR lease_until <= ?', Time.current)
                        .update_all(lease_token: @token, lease_until: Time.current + LEASE) == 1
    end

    def commit
      EditorialSyncState.transaction do
        held = EditorialSyncState.where(id: @state.id, lease_token: @token).where('lease_until > ?', Time.current)
                                 .update_all(lease_until: Time.current + LEASE)
        raise LostLease, 'Editorial runner lease expired or replaced; replay checkpoint' unless held == 1

        yield
      end
    end

    def import_pages(pages, size)
      start_window(size)
      result = nil
      imported = 0
      pages.times do
        commit { @state.reload }
        result = @sync.call(page: @state.next_page, max_pages: 1, per_page: @state.per_page,
                            after: @state.window_after&.utc&.iso8601, before: @state.window_before.utc.iso8601)
        result[:imported] += imported
        imported = result[:imported]
        # Never skip a poisoned page. Valid neighbors can be safely replayed.
        if result[:invalid_ids].any?
          result[:next_page] = @state.next_page
          break
        end

        checkpoint(result)
        break unless result[:next_page]
      end
      result
    rescue Client::PageDrift => e
      commit { @state.update!(next_page: 1) }
      { error: e.message, replay_from: 1 }
    rescue Client::Unavailable => e
      { error: e.message }
    end

    def start_window(size)
      commit do
        @state.reload
        unless @state.window_before
          @state.update!(window_after: @state.watermark, window_before: Time.current.utc.change(usec: 0),
                         next_page: 1, per_page: size)
        end
      end
    end

    def checkpoint(result)
      commit do
        if result[:watermark]
          @state.update!(watermark: result[:watermark], window_after: nil, window_before: nil,
                         next_page: 1, per_page: nil)
        else
          @state.update!(next_page: result.fetch(:next_page))
        end
      end
    end
  end
end
