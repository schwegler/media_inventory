# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Category
  TYPES = {
    'genres' => {
      title: 'Genres',
      singular: 'Genre',
      attribute: :genre,
      models: -> { [Movie, TvShow, Album] }
    },
    'directors' => {
      title: 'Directors',
      singular: 'Director',
      attribute: :director,
      models: -> { [Movie, TvShow] }
    },
    'actors' => {
      title: 'Actors',
      singular: 'Actor',
      attribute: :actors,
      models: -> { [Movie, TvShow] }
    },
    'platforms' => {
      title: 'Platforms',
      singular: 'Platform',
      attribute: :platform,
      models: -> { [VideoGame] }
    },
    'writers' => {
      title: 'Writers',
      singular: 'Writer',
      attribute: :writer,
      models: -> { [Movie, TvShow, Comic] }
    }
  }.merge({
            'artists' => { title: 'Music Artists', singular: 'Artist', attribute: :artist, models: -> { [Album] } },
            'comic-creators' => { title: 'Comic Creators', singular: 'Creator', attribute: :writer, models: lambda {
              [Comic]
            } },
            'authors' => { title: 'Authors', singular: 'Author', attribute: :author, models: -> { [Book] } },
            'publishers' => { title: 'Publishers', singular: 'Publisher', attribute: :publisher,
                              models: -> { [Book, Comic, VideoGame] } },
            'developers' => { title: 'Developers', singular: 'Developer', attribute: :developer, models: lambda {
              [VideoGame]
            } },
            'networks' => { title: 'Networks', singular: 'Network', attribute: :network, models: -> { [TvShow] } }
          }).freeze

  attr_reader :name, :type, :count

  def initialize(name:, type:, count: 0)
    @name = name
    @type = type.to_s
    @count = count
  end

  def self.valid_type?(type)
    TYPES.key?(type.to_s)
  end

  def self.config_for(type)
    TYPES[type.to_s]
  end

  def self.title_for(type)
    config_for(type)&.fetch(:title, type.to_s.titleize)
  end

  def self.singular_for(type)
    config_for(type)&.fetch(:singular, type.to_s.singularize.titleize)
  end

  def self.split_names(raw)
    return [] if raw.blank?

    raw.to_s.split(%r{[,/;|]+}).map(&:strip).reject(&:blank?)
  end

  def self.list_for(type, query: nil, sort: :count, limit: nil)
    config = config_for(type)
    return [] unless config

    categories = entity_categories(type)
    legacy = aggregate_categories(config[:models].call, config[:attribute], type)
    categories = combine_counts(categories, legacy)
    categories = filter_by_query(categories, query) if query.present?
    sorted = sort_categories(categories, sort)
    limit ? sorted.first(limit.to_i) : sorted
  end

  ENTITY_ROLES = {
    'actors' => ['Actor', 'Guest star'], 'directors' => ['Director'], 'writers' => %w[Writer Screenwriter],
    'artists' => ['Album artist', 'Track artist', 'Featured artist', 'Performer', 'Composer', 'Producer'],
    'authors' => %w[Author Illustrator Translator Narrator], 'publishers' => ['Publisher'],
    'developers' => ['Developer'], 'networks' => ['Network'], 'platforms' => ['Platform'], 'genres' => ['Genre']
  }.freeze

  def self.entity_credits(type)
    credits = MetadataCredit.all
    if type == 'comic-creators'
      return credits.where(item_type: %w[Comic ComicIssue]).joins(:metadata_entity)
                    .where(metadata_entities: { kind: %w[person artist] })
    end

    credits = credits.where(role: ENTITY_ROLES.fetch(type, []))
    credits = credits.where(item_type: %w[Album AlbumTrack]) if type == 'artists'
    credits
  end

  def self.entity_categories(type)
    works = entity_credits(type).select(:metadata_entity_id, :item_type, :item_id).distinct
    counts = MetadataCredit.from("(#{works.to_sql}) counted_works").group(:metadata_entity_id).count
    return [] if counts.empty?

    MetadataEntity.where(id: counts.keys).pluck(:id, :name).map do |id, name|
      new(name: name, type: type, count: counts[id] || 0)
    end
  end

  def self.combine_counts(categories, legacy)
    (categories + legacy).group_by { |category| category.name.downcase }.map do |_key, entries|
      first = entries.first
      new(name: first.name, type: first.type, count: entries.sum(&:count))
    end
  end

  def self.aggregate_categories(models, attribute, type)
    counts = Hash.new(0)
    casing = {}
    attributes = type == 'comic-creators' ? %i[writer artist] : [attribute]
    models.each do |m|
      attributes.each { |attr| count_model_attributes(m, attr, counts, casing) }
    end
    counts.map { |key, count| new(name: casing[key], type: type, count: count) }
  end

  def self.count_model_attributes(model, attribute, counts, casing)
    return unless model.column_names.include?(attribute.to_s)

    model.where.not(id: MetadataCredit.where(item_type: model.name).select(:item_id))
         .where.not(attribute => [nil, '']).pluck(attribute).each do |raw|
      split_names(raw).each do |name|
        key = name.downcase
        casing[key] ||= name
        counts[key] += 1
      end
    end
  end

  def self.filter_by_query(categories, query)
    q = query.to_s.strip.downcase
    categories.select { |cat| cat.name.downcase.include?(q) }
  end

  def self.sort_categories(categories, sort)
    if sort.to_s == 'name'
      categories.sort_by { |cat| cat.name.downcase }
    else
      categories.sort_by { |cat| [-cat.count, cat.name.downcase] }
    end
  end

  def self.items_for(type, name, media_type: nil, sort: :newest)
    config = config_for(type)
    return [] unless config && name.present?

    credits = entity_credits(type).joins(:metadata_entity)
                                  .where(metadata_entities: { normalized_name: MetadataEntity.normalize(name) })
    matched = credits.pluck(:item_type, :item_id).uniq.group_by(&:first).flat_map do |kind, entries|
      model = kind.constantize
      next [] if media_type.present? && !media_type_matches?(model, media_type)

      entity_items(model, entries.map(&:last))
    end

    attributes = type == 'comic-creators' ? %i[writer artist] : [config[:attribute]]
    matched += config[:models].call.flat_map do |model|
      next [] if media_type.present? && !media_type_matches?(model, media_type)

      attributes.flat_map { |attr| fetch_model_items(model, attr, name) }
    end
    sort_items(matched.uniq, sort)
  end

  def self.entity_items(model, ids)
    scope = model.where(id: ids)
    scope = scope.with_attached_cover_image if scope.respond_to?(:with_attached_cover_image)
    scope = scope.includes(:library_items) if model.reflect_on_association(:library_items)
    scope = scope.includes(:comic) if model == ComicIssue
    scope = scope.includes(:tv_show) if model == TvEpisode
    scope.to_a
  end

  def self.fetch_model_items(model, attribute, name)
    search_name = name.to_s.strip.downcase
    sanitized = model.sanitize_sql_like(search_name, '!')
    scope = model.where.not(id: MetadataCredit.where(item_type: model.name).select(:item_id))
    scope = scope.with_attached_cover_image if scope.respond_to?(:with_attached_cover_image)

    scope.where(like_clause(attribute), exact: search_name, starts: "#{sanitized},%",
                                        ends: "%, #{sanitized}", middle: "%, #{sanitized},%",
                                        substr: "%#{sanitized}%")
         .select { |record| split_names(record.public_send(attribute)).any? { |v| v.casecmp?(name.to_s.strip) } }
  end

  def self.like_clause(attribute)
    "LOWER(#{attribute}) = :exact OR " \
      "LOWER(#{attribute}) LIKE :starts ESCAPE '!' OR " \
      "LOWER(#{attribute}) LIKE :ends ESCAPE '!' OR " \
      "LOWER(#{attribute}) LIKE :middle ESCAPE '!' OR " \
      "LOWER(#{attribute}) LIKE :substr ESCAPE '!'"
  end

  def self.media_type_matches?(model, media_type)
    case media_type.to_s
    when 'movies', 'movie' then model == Movie
    when 'tv_shows', 'tv_show', 'tv' then [TvShow, TvEpisode].include?(model)
    when 'albums', 'album' then [Album, AlbumTrack].include?(model)
    when 'comics', 'comic' then [Comic, ComicIssue].include?(model)
    when 'video_games', 'video_game' then model == VideoGame
    when 'books', 'book' then model == Book
    else true
    end
  end

  def self.sort_items(items, sort)
    case sort.to_s
    when 'title'
      items.sort_by { |i| i.title.to_s.downcase }
    when 'year'
      items.sort_by { |i| [-(i.try(:release_year) || 0), i.title.to_s.downcase] }
    else
      items.sort_by do |i|
        timestamp = i.try(:updated_at) || i.try(:created_at)
        -(timestamp ? timestamp.to_i : 0)
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
