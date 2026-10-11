# frozen_string_literal: true

# Every personal predicate is scoped to the signed-in user's shelf.
class MediaLibraryQuery
  METADATA = {
    'Movie' => %w[director genre], 'TvShow' => %w[network genre],
    'Book' => %w[author publisher], 'Album' => %w[artist genre],
    'Comic' => %w[publisher writer artist]
  }.freeze

  def initialize(klass, user:, filters:)
    @klass = klass
    @filters = filters
    @libraries = user.library_items.where(item_type: klass.name)
  end

  def call(scope)
    libraries = filtered_libraries
    if @filters['format'].present?
      libraries = libraries.where(owned_physically_format: @filters['format'])
                           .or(libraries.where(owned_digitally_format: @filters['format']))
    end
    scope = scope.joins(:library_items).where(library_items: { id: libraries.select(:id) })
    METADATA.fetch(@klass.name).each do |field|
      next if @filters[field].blank?

      column = @klass.arel_table[field].lower
      scope = scope.where(column.matches("%#{@klass.sanitize_sql_like(@filters[field].to_s.strip.downcase)}%", '\\', true))
    end
    if @klass.column_names.include?('release_year') && @filters['year'].to_s.match?(/\A\d{4}\z/)
      scope = scope.where(release_year: @filters['year'])
    end
    sort(scope)
  end

  def statistics
    { all: @libraries.count, backlog: @libraries.where(in_backlog: true).count,
      finished: @libraries.where(consumed: true).count, collection: @libraries.where(is_collected: true).count,
      progress: @libraries.where(id: ConsumptionPass.active.select(:library_item_id)).count }
  end

  private

  def filtered_libraries
    case @filters['status']
    when 'collection' then @libraries.where(is_collected: true)
    when 'backlog' then @libraries.where(in_backlog: true)
    when 'finished' then @libraries.where(consumed: true)
    when 'unfinished' then @libraries.where(consumed: [false, nil])
    when 'unrated' then @libraries.where(rating: [nil, ''])
    when 'physical' then @libraries.where(owned_physically: true)
    when 'digital' then @libraries.where(owned_digitally: true)
    when 'progress'
      @libraries.where(id: ConsumptionPass.active.where(library_item_id: @libraries.select(:id)).select(:library_item_id))
    else @libraries
    end
  end

  def sort(scope)
    order = case @filters['sort']
            when 'title' then @klass.arel_table[:title].lower.asc
            when 'oldest' then LibraryItem.arel_table[:created_at].asc
            when 'finished' then Arel.sql('library_items.consumed_at DESC NULLS LAST')
            when 'rating' then Arel.sql("#{GameLibraryQuery::RATING_SQL} DESC NULLS LAST")
            else LibraryItem.arel_table[:created_at].desc
            end
    scope.order(order, @klass.arel_table[:id].asc)
  end
end
