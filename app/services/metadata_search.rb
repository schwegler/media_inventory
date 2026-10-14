# frozen_string_literal: true

# Relationship subqueries preserve one row per work, including before pagination.
class MetadataSearch
  CHILDREN = { 'Album' => [AlbumTrack, :album_id], 'Comic' => [ComicIssue, :comic_id],
               'TvShow' => [TvEpisode, :tv_show_id] }.freeze

  def self.call(scope, query, rank: true)
    return scope if query.blank?

    new(scope, query).call(rank: rank)
  end

  def initialize(scope, query)
    @scope = scope
    @model = scope.klass
    @query = MetadataEntity.normalize(query).first(200)
    @pattern = "%#{@model.sanitize_sql_like(@query, '!')}%"
  end

  def call(rank: true)
    title = @model.arel_table[@model == TvEpisode ? :name : :title].lower
    predicate = title.matches(@pattern, '!', true).or(@model.arel_table[:id].in(credit_ids(@model)))
    predicate = predicate.or(@model.arel_table[:id].in(child_ids)) if CHILDREN.key?(@model.name)
    legacy_columns.each do |field|
      predicate = predicate.or(@model.arel_table[field].lower.matches(@pattern, '!', true))
    end
    scope = @scope.where(predicate)
    rank ? scope.reorder(ranking(title), @model.arel_table[:id].asc) : scope
  end

  private

  def legacy_columns
    MetadataEntitySync::FIELDS.fetch(@model.name, {}).keys
  end

  def credit_ids(model, entities = MetadataEntity.matching(@query).reorder(nil))
    MetadataCredit.where(item_type: model.name,
                         metadata_entity_id: entities.select(:id))
                  .select(:item_id).arel
  end

  def child_ids
    child, foreign_key = CHILDREN.fetch(@model.name)
    self.class.call(child.all, @query, rank: false).select(foreign_key).arel
  end

  def ranking(title)
    exact = MetadataEntity.where(normalized_name: @query)
    prefix = MetadataEntity.where("normalized_name LIKE ? ESCAPE '!'", "#{@model.sanitize_sql_like(@query, '!')}%")
    id = @model.arel_table[:id]
    Arel::Nodes::Case.new.when(title.eq(@query)).then(0)
                     .when(title.matches("#{@model.sanitize_sql_like(@query, '!')}%", '!', true)).then(1)
                     .when(title.matches(@pattern, '!', true)).then(2)
                     .when(id.in(credit_ids(@model, exact))).then(3)
                     .when(id.in(credit_ids(@model, prefix))).then(4).else(5)
  end
end
