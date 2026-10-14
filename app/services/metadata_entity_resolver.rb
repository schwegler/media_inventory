# frozen_string_literal: true

# Exact identifiers win. Never reconcile different provider IDs by fuzzy names.
class MetadataEntityResolver
  def self.call(row)
    kind = row.fetch('kind', 'person')
    normalized = MetadataEntity.normalize(row['name'])
    identity = row.values_at('provider', 'external_id')
    entity = MetadataIdentity.find_by(provider: identity[0], external_id: identity[1])&.metadata_entity if
      identity.all?(&:present?)
    entity ||= fallback(kind, normalized, identity)
    entity ||= MetadataEntity.create_or_find_by!(identity_key: key(kind, normalized, identity)) do |record|
      record.kind = kind
      record.name = row['name']
    end
    enrich(entity, row, identity)
  end

  def self.fallback(kind, normalized, identity)
    kinds = %w[person artist].include?(kind) ? %w[person artist] : [kind]
    scope = MetadataEntity.where(kind: kinds, normalized_name: normalized)
    if identity.all?(&:present?)
      scope = scope.where.not(id: MetadataIdentity.where(provider: identity[0]).select(:metadata_entity_id))
    end
    candidates = scope.limit(2).to_a
    candidates.first if candidates.one?
  end

  def self.key(kind, normalized, identity)
    identity.all?(&:present?) ? "#{kind}:#{identity.join(':')}" : "#{kind}:name:#{normalized}"
  end

  def self.enrich(entity, row, identity)
    if identity.all?(&:present?)
      binding = entity.metadata_identities.create_or_find_by!(provider: identity[0], external_id: identity[1])
      entity = binding.metadata_entity
    end
    names = entity.aliases + Array(row['aliases']) + [row['name']]
    entity.aliases = names.compact_blank.uniq.reject { |name| MetadataEntity.normalize(name) == entity.normalized_name }
    entity.description ||= row['description'].presence
    entity.thumbnail_url ||= MetadataProvider.image(row['image'])
    entity.save! if entity.changed?
    entity
  end
end
