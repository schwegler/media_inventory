# frozen_string_literal: true

# Bounded metadata cache even when Rails' page cache is disabled. No binary media
# is held here. Limit background HTTP/download workers in the built-in adapter.
if !Rails.env.test? && [nil, :async].include?(Rails.application.config.active_job.queue_adapter)
  Rails.application.config.active_job.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new(
    min_threads: 1, max_threads: Integer(ENV.fetch('MEDIA_IMPORT_THREADS', '2')).clamp(1, 4), idletime: 60
  )
end
