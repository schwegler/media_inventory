# frozen_string_literal: true

module LibraryItemFormAttributes
  extend ActiveSupport::Concern

  included do
    attr_accessor :is_collected, :in_watchlist, :in_backlog, :rating, :review, :consumed, :consumed_at, :is_public,
                  :owned_physically, :owned_physically_format, :owned_digitally, :owned_digitally_format

    # rubocop:disable Naming/PredicatePrefix
    def is_collected?
      !!is_collected
    end
    # rubocop:enable Naming/PredicatePrefix

    def in_watchlist?
      !!in_watchlist
    end

    def in_backlog?
      !!in_backlog
    end

    def consumed?
      !!consumed
    end
  end
end
