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
    candidates = publicly_addressable(FavoriteShelf).order(updated_at: :desc, id: :desc)
                                                    .limit(CANDIDATE_LIMIT).select(:id)
    records = containing(FavoriteShelf.where(id: candidates)).includes(:user)
                                                             .order(updated_at: :desc, id: :desc).limit(@limit).to_a
    resolve_previews(records)
    records.map { |record| entry(record) }
  end

  private

  # Match homepage discovery opt-in: confirmed handled accounts with a published
  # preview. Named collections remain direct-link only, as on the homepage.
  # A future visibility mode must also update show/OG/profile gates.
  def publicly_addressable(model)
    users = User.where.not(confirmed_at: nil).where.not(username: [nil, ''])
                .joins(:shelf_previews_attachments).select(:id)
    model.where(user_id: users)
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
    { title: FavoriteShelf::CATEGORIES[record.category],
      creator: { name: record.user.name, username: record.user.username },
      url: Rails.application.routes.url_helpers.shelf_path(record.user.username, category: record.category),
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
