# frozen_string_literal: true

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

    raw.to_s.split(/[,\/;|]+/).map(&:strip).reject(&:blank?)
  end

  def self.list_for(type, query: nil, sort: :count, limit: nil)
    config = config_for(type)
    return [] unless config

    models = config[:models].call
    attribute = config[:attribute]

    name_counts = Hash.new(0)
    canonical_casing = {}

    models.each do |model|
      next unless model.column_names.include?(attribute.to_s)

      model.where.not(attribute => [nil, '']).pluck(attribute).each do |raw_value|
        split_names(raw_value).each do |clean_name|
          key = clean_name.downcase
          canonical_casing[key] ||= clean_name
          name_counts[key] += 1
        end
      end
    end

    results = name_counts.map do |key, count|
      new(name: canonical_casing[key], type: type, count: count)
    end

    if query.present?
      q = query.to_s.strip.downcase
      results.select! { |cat| cat.name.downcase.include?(q) }
    end

    results = case sort.to_s
              when 'name'
                results.sort_by { |cat| cat.name.downcase }
              else
                results.sort_by { |cat| [-cat.count, cat.name.downcase] }
              end

    limit ? results.first(limit.to_i) : results
  end

  def self.items_for(type, name, media_type: nil, sort: :newest)
    config = config_for(type)
    return [] unless config && name.present?

    models = config[:models].call
    attribute = config[:attribute]
    search_name = name.to_s.strip.downcase

    matched = []

    models.each do |model|
      next unless model.column_names.include?(attribute.to_s)
      next if media_type.present? && !media_type_matches?(model, media_type)

      scope = model.all
      scope = scope.with_attached_cover_image if scope.respond_to?(:with_attached_cover_image)

      sanitized = model.sanitize_sql_like(search_name, '!')
      records = scope.where(
        "LOWER(#{attribute}) = :exact OR " \
        "LOWER(#{attribute}) LIKE :starts ESCAPE '!' OR " \
        "LOWER(#{attribute}) LIKE :ends ESCAPE '!' OR " \
        "LOWER(#{attribute}) LIKE :middle ESCAPE '!' OR " \
        "LOWER(#{attribute}) LIKE :substr ESCAPE '!'",
        exact: search_name,
        starts: "#{sanitized},%",
        ends: "%, #{sanitized}",
        middle: "%, #{sanitized},%",
        substr: "%#{sanitized}%"
      )

      # In-memory filter to ensure exact token match within comma-separated list
      filtered = records.select do |record|
        values = split_names(record.public_send(attribute))
        values.any? { |v| v.casecmp?(name.to_s.strip) }
      end

      matched.concat(filtered)
    end

    sort_items(matched, sort)
  end

  def self.media_type_matches?(model, media_type)
    case media_type.to_s
    when 'movies', 'movie' then model == Movie
    when 'tv_shows', 'tv_show', 'tv' then model == TvShow
    when 'albums', 'album' then model == Album
    when 'comics', 'comic' then model == Comic
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
      items.sort_by { |i| -(i.created_at&.to_i || 0) }
    end
  end
end
