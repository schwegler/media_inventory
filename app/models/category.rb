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
  }.freeze

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

    categories = aggregate_categories(config[:models].call, config[:attribute], type)
    categories = filter_by_query(categories, query) if query.present?
    sorted = sort_categories(categories, sort)
    limit ? sorted.first(limit.to_i) : sorted
  end

  def self.aggregate_categories(models, attribute, type)
    counts = Hash.new(0)
    casing = {}
    models.each { |m| count_model_attributes(m, attribute, counts, casing) }
    counts.map { |key, count| new(name: casing[key], type: type, count: count) }
  end

  def self.count_model_attributes(model, attribute, counts, casing)
    return unless model.column_names.include?(attribute.to_s)

    model.where.not(attribute => [nil, '']).pluck(attribute).each do |raw|
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

    attribute = config[:attribute]
    matched = config[:models].call.flat_map do |model|
      next [] if media_type.present? && !media_type_matches?(model, media_type)
      next [] unless model.column_names.include?(attribute.to_s)

      fetch_model_items(model, attribute, name)
    end

    sort_items(matched, sort)
  end

  def self.fetch_model_items(model, attribute, name)
    search_name = name.to_s.strip.downcase
    sanitized = model.sanitize_sql_like(search_name, '!')
    scope = model.all
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
    when 'tv_shows', 'tv_show', 'tv' then model == TvShow
    when 'albums', 'album' then model == Album
    when 'comics', 'comic' then model == Comic
    when 'video_games', 'video_game' then model == VideoGame
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
