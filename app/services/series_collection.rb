# frozen_string_literal: true

# Page before preloading artwork, credits or personal review bodies. Counts and
# completion predicates remain database-backed across the entire series.
class SeriesCollection
  PAGE_SIZE = 30
  attr_reader :series, :records, :total, :completed, :pass, :libraries, :entry_ids,
              :seasons, :season, :query, :status, :season_total, :season_completed

  def initialize(series, user:, library:, params: {})
    @series = series
    @scope = tv? ? series.tv_episodes : series.comic_issues
    @user = user
    @library = library
    @pass = ConsumptionPasses.current_pass(library)
    @total = @scope.count
    @done = completed_scope
    @completed = @done.count
    @query = params[:child_q].to_s.strip.first(200)
    @status = %w[true false].include?(params[:child_status]) ? params[:child_status] : 'all'
    select_season(params[:season])
    load_records(params[:entries_page])
  end

  def tv? = series.is_a?(TvShow)

  def filters
    { season: season, child_q: query.presence, child_status: status, series_page: '1',
      entries_page: records.current_page }.compact
  end

  private

  def completed_scope
    return @scope.none unless @user

    ids = if pass&.rewatch?
            pass.entries.where(item_type: @scope.klass.name).select(:item_id)
          else
            @user.library_items.where(item_type: @scope.klass.name, consumed: true).select(:item_id)
          end
    @scope.where(id: ids)
  end

  def select_season(value)
    @seasons = tv? ? @scope.distinct.order(:season).pluck(:season) : []
    @season = if tv?
                if value == 'all' || (value.blank? && query.present?)
                  'all'
                else
                  seasons.find do |s|
                    s.to_s == value.to_s
                  end || seasons.first
                end
              end
    @selected = tv? && season != 'all' ? @scope.where(season: season) : @scope
    @season_total = @selected.count
    @season_completed = @selected.where(id: @done.select(:id)).count
  end

  def load_records(page)
    scope = MetadataSearch.call(@selected, query)
    if query.match?(/\A\d+\z/)
      matches = scope.reorder(nil).select(:id)
      scope = @selected.where(id: matches).or(@selected.where((tv? ? :episode : :issue_number) => query.to_i))
    end
    scope = scope.where(id: @done.select(:id)) if status == 'true'
    scope = scope.where.not(id: @done.select(:id)) if status == 'false'
    order = if tv?
              %i[season episode id]
            else
              [Arel.sql('CASE WHEN issue_number IS NULL THEN 1 ELSE 0 END'), :issue_number, :id]
            end
    @records = scope.reorder(*order).with_attached_cover_image
                    .includes(tv? ? :tv_show : :comic, metadata_credits: :metadata_entity)
                    .page(page).per(PAGE_SIZE)
    @records = @records.page([@records.total_pages, 1].max) if @records.current_page > [@records.total_pages, 1].max
    load_personal_state
  end

  def load_personal_state
    ids = records.map(&:id)
    @libraries = @user ? @user.library_items.where(item_type: @scope.klass.name, item_id: ids).index_by(&:item_id) : {}
    @entry_ids = pass ? pass.entries.where(item_type: @scope.klass.name, item_id: ids).pluck(:item_id).to_set : Set.new
  end
end
