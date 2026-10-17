# frozen_string_literal: true

require 'rails_helper'
require 'timeout'
require Rails.root.join('lib/bounded_async_adapter')

RSpec.describe BoundedAsyncAdapter do
  let(:adapter) { described_class.new(capacity: 2) }

  after { adapter.shutdown }

  def wait_until
    Timeout.timeout(3) { Thread.pass until yield }
  end

  it 'bounds admission across running and queued work without running rejected jobs inline' do
    entered = Queue.new
    release = Queue.new
    allow(ActiveJob::Base).to receive(:execute) do
      entered << Thread.current
      release.pop
    end
    job = ActiveJob::Base.new
    adapter.enqueue(job)
    expect(Timeout.timeout(3) { entered.pop }).not_to eq(Thread.current)
    adapter.enqueue(ActiveJob::Base.new)
    expect(adapter.snapshot.slice(:outstanding, :running, :queued)).to eq(outstanding: 2, running: 1, queued: 1)
    expect { adapter.enqueue(ActiveJob::Base.new) }.to raise_error(ActiveJob::EnqueueError)
    2.times { release << true }
    wait_until { adapter.snapshot[:outstanding].zero? }
  ensure
    2.times { release << true } if release
  end

  it 'reserves delayed jobs within the same bound and cancels them on shutdown' do
    allow(ActiveJob::Base).to receive(:execute)
    2.times { adapter.enqueue_at(ActiveJob::Base.new, 1.hour.from_now.to_f) }
    expect(adapter.snapshot[:scheduled]).to eq(2)
    expect { adapter.enqueue(ActiveJob::Base.new) }.to raise_error(ActiveJob::EnqueueError)
    adapter.shutdown
    expect(adapter.snapshot[:outstanding]).to eq(0)
    expect(ActiveJob::Base).not_to have_received(:execute)
    expect { adapter.enqueue(ActiveJob::Base.new) }.to raise_error(ActiveJob::EnqueueError)
  end

  it 'releases failed jobs and exposes only class names, never payloads or exception messages' do
    allow(ActiveJob::Base).to receive(:execute).and_raise(StandardError, 'secret provider token')
    adapter.enqueue(ActiveJob::Base.new('private input'))
    wait_until { adapter.snapshot[:outstanding].zero? }
    expect(adapter.snapshot[:last_failure][:reason]).to eq('StandardError')
    expect(adapter.snapshot.inspect).not_to include('private input', 'secret provider token')
  end
end
