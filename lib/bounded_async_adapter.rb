# frozen_string_literal: true

# One worker with a strict admission bound including scheduled/running jobs.
# This remains intentionally volatile; domain leases and retry paths recover
# interrupted work. Rejection uses Active Job's normal false/enqueue_error API.
class BoundedAsyncAdapter
  def initialize(capacity: 32)
    @capacity = capacity.to_i.clamp(1, 128)
    @mutex = Mutex.new
    @pending = {}
    @scheduled = {}
    @executor = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 1,
                                                   max_queue: @capacity, fallback_policy: :abort)
  end

  def enqueue(job)
    token, payload = admit(job, 'queued')
    post(token, payload)
  end

  def enqueue_at(job, timestamp)
    token, payload = admit(job, 'scheduled')
    task = Concurrent::ScheduledTask.execute([timestamp - Time.now.to_f, 0].max) { post(token, payload) }
    @mutex.synchronize { @scheduled[token] = task if @pending.key?(token) }
  rescue Concurrent::RejectedExecutionError
    release(token)
    raise ActiveJob::EnqueueError, 'Background queue is busy. Please retry.'
  end

  def snapshot
    @mutex.synchronize do
      counts = @pending.values.group_by { |entry| entry[:state] }.transform_values(&:size)
      oldest = @pending.values.map { |entry| entry[:at] }.min
      { capacity: @capacity, outstanding: @pending.size, queued: counts.fetch('queued', 0),
        running: counts.fetch('running', 0), scheduled: counts.fetch('scheduled', 0),
        oldest_seconds: oldest ? (clock - oldest).round : 0, last_failure: @last_failure }
    end
  end

  def shutdown
    tasks = @mutex.synchronize do
      @stopped = true
      @pending.delete_if { |_, entry| entry[:state] == 'scheduled' }
      @scheduled.values.tap { @scheduled = {} }
    end
    tasks.each(&:cancel)
    @executor.shutdown
    @executor.wait_for_termination(5)
  end

  private

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def admit(job, state)
    @mutex.synchronize do
      if @stopped || @pending.size >= @capacity
        @last_failure = { at: Time.now.utc.iso8601, reason: 'Queue full', job_class: job.class.name }
        raise ActiveJob::EnqueueError, 'Background queue is busy. Please retry.'
      end
      token = SecureRandom.uuid
      job.provider_job_id = token
      payload = job.serialize
      @pending[token] = { at: clock, state: state }
      [token, payload]
    end
  end

  def post(token, payload)
    @mutex.synchronize do
      return unless @pending[token]

      @scheduled.delete(token)
      @pending[token][:state] = 'queued'
    end
    @executor.post do
      @mutex.synchronize { @pending[token][:state] = 'running' if @pending[token] }
      begin
        ActiveJob::Base.execute(payload)
      rescue StandardError => e
        @mutex.synchronize do
          @last_failure = { at: Time.now.utc.iso8601, reason: e.class.name, job_class: payload['job_class'] }
        end
      ensure
        release(token)
      end
    end
  rescue Concurrent::RejectedExecutionError
    release(token)
    raise ActiveJob::EnqueueError, 'Background queue is busy. Please retry.'
  end

  def release(token)
    @mutex.synchronize do
      @pending.delete(token)
      @scheduled.delete(token)
    end
  end
end
