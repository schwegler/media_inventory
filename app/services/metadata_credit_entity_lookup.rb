# frozen_string_literal: true

# Read-only, batched lookup for legacy credits without MetadataCredit associations.
# A supplied identity wins; name-only fallbacks must be unambiguous and compatible.
class MetadataCreditEntityLookup
  def self.call(rows)
    new(rows).call
  end

  def initialize(rows)
    @rows = Array(rows).select { |row| row.is_a?(Hash) && row['name'].present? }
  end

  def call
    return {} if @rows.empty?

    load_identities
    names = @rows.map { |row| MetadataEntity.normalize(row['name']) }.uniq
    @candidates = MetadataEntity.where(normalized_name: names).includes(:metadata_identities).group_by(&:normalized_name)
    @rows.index_with { |row| @identities[identity_key(row)] || fallback(row) }
  end

  private

  def load_identities
    pairs = @rows.map { |row| identity_key(row) }.select { |pair| pair.all?(&:present?) }
    @identities = {}
    return if pairs.empty?

    MetadataIdentity.where(provider: pairs.map(&:first), external_id: pairs.map(&:last))
                    .includes(:metadata_entity).each do |identity|
      @identities[[identity.provider, identity.external_id]] = identity.metadata_entity
    end
  end

  def identity_key(row)
    row.values_at('provider', 'external_id').map(&:to_s)
  end

  def fallback(row)
    matches = @candidates.fetch(MetadataEntity.normalize(row['name']), []).select do |entity|
      compatible_kinds(row).include?(entity.kind) && !conflicting_identity?(entity, row)
    end
    matches.first if matches.one?
  end

  def compatible_kinds(row)
    role = ProviderEntityMetadata::ROLES.fetch(row['role'], row['role'].to_s.humanize)
    kind = row['kind'].presence || MetadataEntitySync::KINDS.fetch(role, 'person')
    %w[person artist].include?(kind) ? %w[person artist] : [kind]
  end

  def conflicting_identity?(entity, row)
    return false unless row.values_at('provider', 'external_id').all?(&:present?)

    entity.metadata_identities.any? { |identity| identity.provider == row['provider'] }
  end
end
