# frozen_string_literal: true

# Blank disables paid links. Only the current registered ID is accepted by the helper.
Rails.configuration.x.amazon_associates_tag = ENV.fetch('AMAZON_ASSOCIATES_TAG', 'schweg-20')
