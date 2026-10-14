# frozen_string_literal: true

module ChildCreditsHelper
  def resolve_raw_credits(credits)
    return {} if credits.blank?

    credits_array = credits.grep(Hash)
    return {} if credits_array.empty?

    identity_map = fetch_identities_map(credits_array)

    unresolved_names = credits_array.filter_map do |c|
      pair = identity_pair_for(c)
      MetadataEntity.normalize(c['name']) if pair.nil? || !identity_map.key?(pair)
    end.compact.uniq

    name_map = fetch_unambiguous_name_map(unresolved_names)

    credits_array.each_with_object({}) do |credit, res|
      entity = entity_for_credit(credit, identity_map, name_map)
      res[credit] = entity if entity
    end
  end

  private

  def identity_pair_for(credit)
    provider = credit['provider']
    external_id = credit['external_id'] || credit['provider_id']
    [provider, external_id.to_s] if provider.present? && external_id.present?
  end

  def fetch_identities_map(credits_array)
    pairs = credits_array.filter_map { |c| identity_pair_for(c) }.uniq
    return {} if pairs.empty?

    identities = pairs.filter_map do |provider, external_id|
      MetadataIdentity.find_by(provider: provider, external_id: external_id)
    end

    identities.each_with_object({}) do |id, map|
      map[[id.provider, id.external_id.to_s]] = id.metadata_entity if id.metadata_entity
    end
  end

  def fetch_unambiguous_name_map(names)
    return {} if names.empty?

    grouped = MetadataEntity.where(normalized_name: names).group_by(&:normalized_name)
    grouped.each_with_object({}) do |(norm_name, entities), map|
      map[norm_name] = entities.first if entities.size == 1
    end
  end

  def entity_for_credit(credit, identity_map, name_map)
    pair = identity_pair_for(credit)
    return identity_map[pair] if pair && identity_map.key?(pair)

    norm_name = MetadataEntity.normalize(credit['name'])
    name_map[norm_name]
  end
end
