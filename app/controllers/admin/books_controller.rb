# frozen_string_literal: true

module Admin
  class BooksController < Admin::ApplicationController
    # Security: Use standardized Admin::MediaActions concern instead of custom
    # un-sanitized Net::HTTP parameter interpolation or incomplete merge transactions.
    include Admin::MediaActions
  end
end
