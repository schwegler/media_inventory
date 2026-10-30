# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Editorial::Runner do
  self.use_transactional_tests = false

  before do
    EditorialArticleTitle.delete_all
    EditorialArticle.delete_all
    EditorialSyncState.delete_all
  end

  after do
    EditorialArticleTitle.delete_all
    EditorialArticle.delete_all
    EditorialSyncState.delete_all
  end
  let(:client) { instance_double(Editorial::Client, total_pages: 2) }
  let(:runner) { described_class.new(client: client) }
  let(:post) do
    { 'id' => 42, 'status' => 'publish', 'date_gmt' => '2026-10-20T12:00:00',
      'modified_gmt' => '2026-10-21T12:00:00', 'link' => 'https://tacobout.online/story/',
      'title' => { 'rendered' => 'Story' }, 'content' => { 'rendered' => '', 'protected' => false } }
  end
  let(:state) { EditorialSyncState.find_by!(name: 'tacobout') }

  def pages(&block)
    allow(client).to receive(:fetch) do |**args|
      args[:id] ? post.merge('id' => args[:id]) : block.call(args.fetch(:params))
    end
  end

  it 'freezes exact continuation parameters across invocations and advances only on completion' do
    requests = []
    pages do |params|
      requests << params
      [post.merge('id' => params[:page])]
    end
    runner.call(max_pages: 1, per_page: 1)
    expect(state).to have_attributes(next_page: 2, watermark: nil, per_page: 1)
    frozen_before = state.window_before
    described_class.new(client: client).call(max_pages: 1, per_page: 50)
    expect(requests.last).to eq(requests.first.merge(page: 2))
    expect(state.reload).to have_attributes(watermark: frozen_before, window_before: nil, next_page: 1)
    runner.call(max_pages: 1)
    expect(requests.last[:modified_after]).to eq((frozen_before - 1.second).utc.iso8601)
    expect(EditorialArticle.count).to eq(2)
  end

  it 'retains a committed page and the previous watermark when the next request fails' do
    previous = Time.utc(2026, 10, 22)
    EditorialSyncState.create!(name: 'tacobout', watermark: previous)
    pages do |params|
      raise Editorial::Client::Unavailable, 'offline' if params[:page] == 2

      [post]
    end
    result = runner.call(per_page: 1)
    expect(result.dig(:import, :error)).to eq('offline')
    expect(state).to have_attributes(next_page: 2, watermark: previous)
    expect(EditorialArticle.count).to eq(1)
    pages { |_params| [post.merge('id' => 43)] }
    runner.call(per_page: 50, max_pages: 1)
    expect(state.reload.watermark).to be > previous
  end

  it 'cannot forget an invalid early page on a later run with valid pages' do
    pages { |params| params[:page] == 1 ? [post, { 'id' => 99 }] : [] }
    2.times { runner.call(per_page: 2) }
    expect(state).to have_attributes(watermark: nil, next_page: 1)
    expect(EditorialArticle.count).to eq(1)
    pages { |params| params[:page] == 1 ? [post, post.merge('id' => 99)] : [] }
    runner.call(per_page: 2)
    expect(state.reload.watermark).to be_present
  end

  it 'replays partial page imports after interruption without advancing the checkpoint' do
    pages { |_params| [post, post.merge('id' => 43)] }
    importer = Editorial::PostImport.new
    allow(Editorial::PostImport).to receive(:new).and_return(importer)
    allow(importer).to receive(:call).and_call_original
    allow(importer).to receive(:call).with(post.merge('id' => 43)).and_raise(Interrupt)
    interrupted = described_class.new(client: client)
    expect { interrupted.call(per_page: 2) }.to raise_error(Interrupt)
    expect(state).to have_attributes(next_page: 1, watermark: nil, lease_token: nil)
    expect(EditorialArticle.count).to eq(1)
    allow(importer).to receive(:call).and_call_original
    interrupted.call(per_page: 2, max_pages: 1)
    expect(EditorialArticle.count).to eq(2)
    expect(state.reload.next_page).to eq(2)
  end

  it 'continues removal rotation after a listing failure and includes suppressed records' do
    article = Editorial::PostImport.new.call(post)
    article.update!(published: false)
    other = Editorial::PostImport.new.call(post.merge('id' => 43))
    pages { |_params| raise Editorial::Client::Unavailable, 'offline' }
    allow(client).to receive(:fetch).with(id: 42, params: { context: 'view' }).and_raise(Editorial::Client::Unavailable)
    result = runner.call(recheck_limit: 1)
    expect(result.dig(:import, :error)).to eq('offline')
    expect(result.dig(:recheck, :unavailable_ids)).to eq([42])
    expect(article.reload.published).to be false
    expect(article.checked_at).to be > other.checked_at
    expect(runner.call(recheck_limit: 1).dig(:recheck, :checked)).to eq(1)
    expect(other.reload.published).to be true
  end

  it 'resets rejected offset pages without changing window or watermark or suppressing articles' do
    pages { |_params| [post] }
    runner.call(per_page: 1, max_pages: 1)
    before = state.window_before
    pages { |_params| raise Editorial::Client::PageDrift, 'page rejected' }
    result = runner.call
    expect(result.dig(:import, :replay_from)).to eq(1)
    expect(state.reload).to have_attributes(next_page: 1, window_before: before, watermark: nil)
    expect(EditorialArticle.first.published).to be true
  end

  it 'rejects concurrent invocations and recovers expired leases' do
    EditorialSyncState.create!(name: 'tacobout', lease_token: 'other', lease_until: 1.minute.from_now)
    expect(runner.call).to eq(status: 'busy')
    state.update!(lease_until: 1.minute.ago)
    pages { |_params| [] }
    expect(runner.call[:status]).to eq('ok')
  end

  it 'fences cache writes and checkpoints if a worker loses ownership during a request' do
    pages do |_params|
      state.update!(lease_token: 'replacement', lease_until: 1.minute.from_now)
      [post]
    end
    expect { runner.call }.to raise_error(described_class::LostLease)
    expect(EditorialArticle.count).to eq(0)
    expect(state.reload).to have_attributes(next_page: 1, watermark: nil, lease_token: 'replacement')
  end

  it 'allows only one worker to fetch while another connection invokes the runner' do
    entered = Queue.new
    release = Queue.new
    pages do |_params|
      entered << true
      release.pop
      []
    end
    worker = Thread.new { ActiveRecord::Base.connection_pool.with_connection { runner.call } }
    begin
      Timeout.timeout(10) { entered.pop }
      expect(described_class.new(client: client).call).to eq(status: 'busy')
    ensure
      release << true
      worker.value
    end
    expect(state.watermark).to be_present
  end

  it 'validates budgets before creating state or fetching' do
    [{ max_pages: 0 }, { max_pages: 21 }, { per_page: 51 }, { recheck_limit: 101 }].each do |options|
      expect { runner.call(**options) }.to raise_error(ArgumentError)
    end
    expect(EditorialSyncState.count).to eq(0)
  end
end
