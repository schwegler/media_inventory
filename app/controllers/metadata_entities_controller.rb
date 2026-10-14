# frozen_string_literal: true

class MetadataEntitiesController < ApplicationController
  before_action :select_library
  before_action :logged_in_user, if: -> { @library == 'mine' }
  before_action :load_entity, only: :show

  def index
    @query = params[:q].to_s.strip.first(200)
    @entities = MetadataEntity.where(id: filtered_credits.select(:metadata_entity_id))
    @entities = @entities.where(kind: params[:kind]) if MetadataEntity::KINDS.include?(params[:kind])
    @entities = @entities.matching(@query) if @query.present?
    count = '(SELECT COUNT(*) FROM metadata_credits WHERE metadata_credits.metadata_entity_id = metadata_entities.id) DESC'
    order = params[:sort] == 'count' ? Arel.sql(count) : :normalized_name
    @entities = @entities.reorder(order, :normalized_name, :id).with_attached_cover_image.page(params[:page]).per(48)
    @entities.each { |entity| RefreshEntityPortraitJob.request(entity) }
    @counts = filtered_credits.where(metadata_entity_id: @entities.map(&:id)).group(:metadata_entity_id).count
  end

  def show
    return if redirect_to_canonical_url(@entity)

    RefreshEntityPortraitJob.request(@entity)
    credits = filtered_credits.where(metadata_entity: @entity)
    all_credits = filtered_credits_without_role.where(metadata_entity: @entity)
    @roles = all_credits.group(:role).count
    @work_count = all_credits.distinct.pluck(:item_type, :item_id).size
    representatives = credits.group(:item_type, :item_id).select('MIN(metadata_credits.id)')
    @work_pages = MetadataCredit.where(id: representatives).order(:item_type, :item_id).page(params[:page]).per(24)
    selections = @work_pages.group_by(&:item_type).map do |type, works|
      credits.where(item_type: type, item_id: works.map(&:item_id))
    end
    @credits = selections.empty? ? credits.none : selections.reduce(&:or).order(:role, :position, :id).preload(:item)
    preload_work_parents
    preload_work_artwork
    @groups = @credits.group_by(&:item_type)
  end

  private

  def select_library
    @library = params[:library].presence || (logged_in? ? 'mine' : 'all')
  end

  def preload_work_parents
    items = @credits.map(&:item).compact
    { AlbumTrack => :album, ComicIssue => :comic, TvEpisode => :tv_show }.each do |model, association|
      records = items.grep(model)
      ActiveRecord::Associations::Preloader.new(records: records, associations: association).call
    end
  end

  def load_entity
    @entity = MetadataEntity.find(params[:id])
  end

  def filtered_credits_without_role
    filtered_credits(apply_role: false)
  end

  def preload_work_artwork
    items = @credits.map(&:item).compact
    artwork = items.map { |item| item.is_a?(AlbumTrack) ? item.album : item }
    ActiveRecord::Associations::Preloader.new(records: artwork, associations: { cover_image_attachment: :blob }).call
  end

  def filtered_credits(apply_role: true)
    credits = MetadataCredit.all
    credits = credits.where(role: params[:role].to_s.first(80)) if apply_role && params[:role].present?
    types = MetadataEntitySync::FIELDS.keys + %w[ComicIssue TvEpisode AlbumTrack]
    credits = credits.where(item_type: params[:media_type]) if types.include?(params[:media_type])
    return credits unless @library == 'mine'

    response.headers['Cache-Control'] = 'private, no-store'
    owned_credits(credits, types)
  end

  def owned_credits(credits, types)
    owned = types.map do |type|
      ids = current_user.library_items.where(item_type: type).select(:item_id)
      matches = credits.where(item_type: type, item_id: ids)
      if (parent = { 'AlbumTrack' => ['Album', :album_id], 'ComicIssue' => ['Comic', :comic_id],
                     'TvEpisode' => ['TvShow', :tv_show_id] }[type])
        parent_ids = current_user.library_items.where(item_type: parent[0]).select(:item_id)
        matches = matches.or(credits.where(item_type: type,
                                           item_id: type.constantize.where(parent[1] => parent_ids).select(:id)))
      end
      matches
    end
    owned.reduce(&:or)
  end
end
