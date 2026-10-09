# frozen_string_literal: true

RSpec.configure do |config|
  config.include ActiveJob::TestHelper, type: :system
  config.around(:each, type: :system) do |example|
    perform_enqueued_jobs(only: [MediaSearchJob, SyncSeriesMetadataJob, RefreshMediaMetadataJob]) { example.run }
  end
end
