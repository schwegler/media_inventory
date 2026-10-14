# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RefreshEntityPortraitJob, type: :job do
  it 'queues at most one lookup per person per month, including negative results' do
    entity = MetadataEntity.create!(name: 'Portrait Person', kind: 'person')
    expect do
      3.times do
        described_class.request(entity)
      end
    end.to have_enqueued_job(described_class).with(entity.id).exactly(:once)
    entity.update!(portrait_checked_at: 31.days.ago)
    expect { described_class.request(entity) }.to have_enqueued_job(described_class).with(entity.id)
  end

  it 'skips nonpeople and existing provider images' do
    entity = MetadataEntity.create!(name: 'A publisher', kind: 'organization')
    expect { described_class.request(entity) }.not_to have_enqueued_job(described_class)
    entity.update!(kind: 'person', thumbnail_url: 'https://image.tmdb.org/t/p/w185/person.jpg')
    expect { described_class.request(entity) }.not_to have_enqueued_job(described_class)
  end
end
