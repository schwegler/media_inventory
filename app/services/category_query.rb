# frozen_string_literal: true

# Union scalar identities, filter/sort/page in SQL, then load only display rows.
# Legacy delimited fields are tokenized in a recursive CTE instead of materialized
# as Ruby model collections. No extra projection table or stale index is needed.
class CategoryQuery
  include CategoryMembershipSql

  MODELS = [Movie, TvShow, Album, Comic, Book, VideoGame, TvEpisode, ComicIssue, AlbumTrack].freeze
  attr_reader :type

  def initialize(type)
    raise ArgumentError, 'Unknown category' unless Category.valid_type?(type)

    @type = type
    @connection = ApplicationRecord.connection
    install_sqlite_fold if sqlite?
  end

  def categories(query: nil, sort: nil, page: 1, per: 48)
    @bindings = {}
    if query.present?
      @bindings[:category_query] = "%#{ApplicationRecord.sanitize_sql_like(query.to_s.strip.downcase, '!')}%"
    end
    filter = query.present? ? "WHERE #{fold('name')} LIKE :category_query ESCAPE '!'" : ''
    grouped = "SELECT MIN(name) AS name, COUNT(*) AS count FROM memberships #{filter} GROUP BY #{fold('name')}"
    total = scalar("SELECT COUNT(*) FROM (#{grouped}) category_counts")
    order = sort.to_s == 'name' ? "#{fold('name')} ASC" : "count DESC, #{fold('name')} ASC"
    offset = page_offset(page, per)
    @bindings.merge!(page_limit: per.to_i, page_offset: offset)
    rows = select("#{grouped} ORDER BY #{order} LIMIT :page_limit OFFSET :page_offset")
    items = rows.map { |row| Category.new(name: row['name'], type: type, count: row['count'].to_i) }
    Kaminari.paginate_array(items, total_count: total, limit: per, offset: offset)
  end

  def items(name, media_type: nil, sort: nil, page: 1, per: 24)
    @bindings = { category_name: MetadataEntity.normalize(name) }
    counts = select('SELECT item_type, COUNT(*) AS count FROM matching GROUP BY item_type', matching: true)
    @counts = counts.to_h { |row| [row['item_type'], row['count'].to_i] }
    models = MODELS.select { |model| media_type.blank? || Category.media_type_matches?(model, media_type) }
    union = models.map { |model| display_select(model) }.join(' UNION ALL ')
    order = case sort.to_s
            when 'title' then "#{fold('sort_title')} ASC"
            when 'year' then "sort_year DESC, #{fold('sort_title')} ASC"
            else 'sort_at DESC'
            end
    offset = page_offset(page, per)
    @bindings.merge!(page_limit: per.to_i, page_offset: offset)
    rows = select(
      "SELECT * FROM (#{union}) display_items ORDER BY #{order}, item_type, item_id " \
      'LIMIT :page_limit OFFSET :page_offset', matching: true
    )
    records = load_page(rows)
    total = models.sum { |model| @counts.fetch(model.name, 0) }
    Kaminari.paginate_array(records, total_count: total, limit: per, offset: offset)
  end

  def media_counts
    result = %w[movies tv_shows albums comics books video_games].index_with { 0 }
    @counts.each do |kind, count|
      model = MODELS.find { |entry| entry.name == kind }
      next unless model

      result.each_key { |key| result[key] += count if Category.media_type_matches?(model, key) }
    end
    result.merge('all' => @counts.values.sum)
  end

  private

  def sqlite? = @connection.adapter_name == 'SQLite'
  def fold(expression) = sqlite? ? "trove_category_fold(#{expression})" : "LOWER(#{expression})"

  def install_sqlite_fold
    # SQLite's built-in LOWER folds ASCII only. Preserve Ruby's existing Unicode
    # category matching while keeping one scalar token at a time in application memory.
    @connection.raw_connection.create_function('trove_category_fold', 1) do |function, value|
      function.result = value.to_s.downcase
    end
  end

  def page_offset(page, per) = ([page.to_i, 1].max - 1) * per

  def select(sql, matching: false)
    prefix = cte
    if matching
      prefix += ', matching AS (SELECT DISTINCT item_type, item_id FROM memberships ' \
                'WHERE match_name = :category_name) '
    end
    binds = @bindings.select { |key, _| sql.include?(":#{key}") || prefix.include?(":#{key}") }
    @connection.select_all(Arel.sql("#{prefix} #{sql}", **binds)).to_a
  end

  def scalar(sql) = select(sql).first.values.first.to_i

  def display_select(model)
    table = model.quoted_table_name
    title = model == TvEpisode ? 'name' : 'title'
    year = model.column_names.include?('release_year') ? 'COALESCE(release_year, 0)' : '0'
    "SELECT #{@connection.quote(model.name)} AS item_type, id AS item_id, COALESCE(#{title}, '') AS sort_title, " \
      "#{year} AS sort_year, updated_at AS sort_at " \
      "FROM #{table} WHERE id IN (SELECT item_id FROM matching WHERE item_type = #{@connection.quote(model.name)})"
  end

  def load_page(rows)
    lookup = rows.group_by { |row| row['item_type'] }.flat_map do |kind, identities|
      model = MODELS.find { |entry| entry.name == kind }
      scope = model.where(id: identities.map { |row| row['item_id'] })
      scope = scope.with_attached_cover_image if model.respond_to?(:with_attached_cover_image)
      scope = scope.includes(:comic) if model == ComicIssue
      scope = scope.includes(:tv_show) if model == TvEpisode
      scope = scope.includes(:album) if model == AlbumTrack
      scope.map { |item| [[kind, item.id], item] }
    end.to_h
    rows.filter_map { |row| lookup[[row['item_type'], row['item_id'].to_i]] }
  end
end
