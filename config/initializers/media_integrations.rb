# frozen_string_literal: true

# Keep HTTP/download jobs inside the web process, with one background thread.
if !Rails.env.test? && [nil, :async].include?(Rails.application.config.active_job.queue_adapter)
  Rails.application.config.active_job.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new(
    min_threads: 1, max_threads: 1, idletime: 60
  )
end
