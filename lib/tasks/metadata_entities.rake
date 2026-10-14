# frozen_string_literal: true

namespace :metadata do
  desc 'Extract stored metadata without API calls (TYPE, ID, AFTER_ID, LIMIT)'
  task backfill_entities: :environment do
    MetadataMaintenance.backfill
  end

  desc 'Opt-in paced enrichment using existing providers (TYPE, ID, AFTER_ID, LIMIT, FORCE, USER_ID, INTERVAL)'
  task enrich: :environment do
    MetadataMaintenance.enrich
  end
end
