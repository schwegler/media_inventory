# frozen_string_literal: true

# One Rails process fits the small Fly machine; ignore WEB_CONCURRENCY.
workers 0
threads Integer(ENV.fetch('RAILS_MIN_THREADS', '1')), Integer(ENV.fetch('RAILS_MAX_THREADS', '3'))
port ENV.fetch('PORT', '3000')
environment ENV.fetch('RAILS_ENV', 'development')
plugin :tmp_restart
