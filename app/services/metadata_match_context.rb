# frozen_string_literal: true

# One query per work/child type, rather than one credit lookup per card.
class MetadataMatchContext
  def self.call(records, query)
    return {} if records.empty? || query.blank?

    model = records.first.class
    matching = MetadataEntity.matching(query).reorder(nil).select(:id)
    context = credit_context(model, records.map(&:id), matching)
    child_config = MetadataSearch::CHILDREN[model.name]
    return context unless child_config

    child, foreign_key = child_config
    children = MetadataSearch.call(child.where(foreign_key => records.map(&:id)), query, rank: false)
    # A card needs one explanation, even for a creator with hundreds of issues.
    candidate_ids = children.reselect(Arel.sql("MIN(#{child.quoted_table_name}.id)")).group(foreign_key)
    children = child.where(id: candidate_ids)
    child_context = credit_context(child, children.select(:id), matching)
    parent = { 'AlbumTrack' => :album, 'ComicIssue' => :comic, 'TvEpisode' => :tv_show }.fetch(child.name)
    children.preload(parent).each do |entry|
      title = entry.respond_to?(:display_title) ? entry.display_title : entry.title
      context[entry.public_send(foreign_key)] ||= "#{title} — #{child_context[entry.id] || 'Title match'}"
    end
    context
  end

  def self.credit_context(model, ids, matching)
    MetadataCredit.where(item_type: model.name, item_id: ids, metadata_entity_id: matching)
                  .includes(:metadata_entity).order(:position, :id).each_with_object({}) do |credit, result|
      result[credit.item_id] ||= "#{credit.role}: #{credit.metadata_entity.name}"
    end
  end
end
