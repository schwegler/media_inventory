# frozen_string_literal: true

# Public selection membership only. Never joins LibraryItem, reviews or progress.
class PublicShelfMembership
  MAX_RESULTS = 12
  CANDIDATE_LIMIT = 500

  def self.call(item, limit: 6)
    return [] unless item&.persisted? && FavoriteShelf::CATEGORIES.except('overall').key?(item.class.name)

    new(item, limit).call
  end

  def initialize(item, limit)
    @item = item
    @limit = limit.to_i.clamp(1, MAX_RESULTS)
  end

  def call
    candidates = recent_candidates
    records = { 'favorite' => FavoriteShelf, 'collection' => ShelfCollection }.flat_map do |kind, model|
      ids = candidates.select { |row| row['shelf_kind'] == kind }.map { |row| row['id'] }
      containing(model.where(id: ids)).includes(:user).to_a
    end
    records = records.sort_by { |record| [record.updated_at, record.id, record.class.name] }.reverse
    @publications = ShelfPublicationLookup.call(records.grep(ShelfCollection))
    records = records.select { |record| current_publication?(record) }.first(@limit)
    resolve_previews(records)
    records.map { |record| entry(record) }
  end

  private

  # Bound the combined window BEFORE examining JSON picks. Named candidates must
  # have a specifically published preview; Ruby verifies its current fingerprint.
  def recent_candidates
    queries = { 'favorite' => FavoriteShelf, 'collection' => ShelfCollection }.map do |kind, model|
      scope = publicly_addressable(model)
      scope = named_publications(scope) if kind == 'collection'
      scope.select(Arel.sql("'#{kind}' AS shelf_kind"), :id, :updated_at).distinct.arel.ast
    end
    union = Arel::Nodes::UnionAll.new(queries[0], queries[1])
    recent = Arel::Table.new(:recent_shelves)
    query = Arel::SelectManager.new.from(Arel::Nodes::TableAlias.new(union, :recent_shelves))
                               .project(recent[Arel.star])
                               .order(recent[:updated_at].desc, recent[:id].desc, recent[:shelf_kind].asc)
                               .take(CANDIDATE_LIMIT)
    ApplicationRecord.connection.select_all(query).to_a
  end

  def publicly_addressable(model)
    users = User.where.not(confirmed_at: nil).where.not(username: [nil, ''])
                .joins(:shelf_previews_attachments).select(:id)
    model.where(user_id: users)
  end

  def named_publications(scope)
    scope = scope.joins(user: { shelf_previews_attachments: :blob })
    scope.where("#{ShelfPublicationLookup.metadata_sql('category')} = ('collection:' || shelf_collections.slug)")
  end

  def current_publication?(record)
    return true unless record.is_a?(ShelfCollection)

    @publications.include?([record.user_id, "collection:#{record.slug}", ShelfCollectionPreviewSignature.call(record)])
  end

  def containing(scope)
    table = scope.model.table_name
    if scope.connection.adapter_name == 'PostgreSQL'
      scope.where("EXISTS (SELECT 1 FROM jsonb_array_elements(#{table}.picks::jsonb) AS selection " \
                  "WHERE selection->>'type' = ? AND selection->>'id' = ?)", @item.class.name, @item.id.to_s)
    else
      scope.where("EXISTS (SELECT 1 FROM json_each(#{table}.picks) AS selection " \
                  "WHERE json_extract(selection.value, '$.type') = ? " \
                  "AND CAST(json_extract(selection.value, '$.id') AS TEXT) = ?)", @item.class.name, @item.id.to_s)
    end
  end

  def resolve_previews(records)
    picks = records.flat_map { |record| Array(record.picks).first(5) }
    @previews = picks.grep(Hash).group_by { |pick| pick['type'] }.filter_map do |type, group|
      next unless FavoriteShelf::CATEGORIES.except('overall').key?(type)

      [type, type.constantize.where(id: group.map { |pick| pick['id'] }).with_attached_cover_image.index_by(&:id)]
    end.to_h
  end

  def entry(record)
    custom = record.is_a?(ShelfCollection)
    params = custom ? { collection: record.slug } : { category: record.category }
    { title: custom ? record.title : FavoriteShelf::CATEGORIES[record.category],
      creator: { name: record.user.name, username: record.user.username },
      url: Rails.application.routes.url_helpers.shelf_path(record.user.username, **params),
      count: record.picks.size, covers: preview_data(record) }
  end

  def preview_data(record)
    Array(record.picks).first(5).filter_map do |pick|
      item = @previews.dig(pick['type'], pick['id'].to_i)
      next unless item

      { title: item.title, type: item.class.name, cover: item.stored_cover_url }
    end
  end
end
