# frozen_string_literal: true

# Narrow current-publication tuples; never instantiates a curator’s preview history.
class ShelfPublicationLookup
  CANDIDATE_LIMIT = 500

  def self.metadata_sql(key)
    raise ArgumentError, 'Unsupported preview field' unless %w[category signature].include?(key)

    if ApplicationRecord.connection.adapter_name == 'PostgreSQL'
      "active_storage_blobs.metadata::jsonb->>'#{key}'"
    else
      "json_extract(active_storage_blobs.metadata, '$.#{key}')"
    end
  end

  def self.call(records)
    return Set.new if records.empty?

    category_sql = metadata_sql('category')
    signature_sql = metadata_sql('signature')
    pairs = records.map do |record|
      expected = ShelfCollectionPreviewSignature.call(record)
      ApplicationRecord.sanitize_sql_array(["(active_storage_attachments.record_id = ? AND #{category_sql} = ? " \
                                            "AND #{signature_sql} = ?)", record.user_id,
                                            "collection:#{record.slug}", expected])
    end
    # DISTINCT exact pairs cap returned metadata at the number of named candidates.
    # Never instantiate every attachment/blob owned by a matched curator.
    candidates = ActiveStorage::Attachment.where(record_type: 'User', name: 'shelf_previews',
                                                 record_id: records.map(&:user_id)).order(id: :desc)
                                          .limit(CANDIDATE_LIMIT).select(:id)
    rows = ActiveStorage::Attachment.where(id: candidates).joins(:blob)
                                    .where(pairs.join(' OR ')).distinct
                                    .pluck(:record_id, Arel.sql(category_sql), Arel.sql(signature_sql))
    rows.to_set
  end
end
