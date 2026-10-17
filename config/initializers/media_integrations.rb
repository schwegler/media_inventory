# frozen_string_literal: true

# Keep HTTP/download jobs inside the web process, with one background thread.
if !Rails.env.test? && [nil, :async].include?(Rails.application.config.active_job.queue_adapter)
  require Rails.root.join('lib/bounded_async_adapter').to_s

  capacity = ENV.fetch('MEDIA_JOB_QUEUE_LIMIT', '32').to_i
  Rails.application.config.active_job.queue_adapter = BoundedAsyncAdapter.new(capacity: capacity)
end
