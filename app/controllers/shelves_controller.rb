# frozen_string_literal: true

# rubocop:disable-next Metrics/ClassLength
class ShelvesController < ApplicationController
  before_action :logged_in_user, only: %i[update search mine]
  before_action :load_user, except: %i[search mine]

  def mine
    if current_user.username.present?
      redirect_to shelf_path(current_user.username)
    else
      redirect_to settings_path, notice: 'Choose a username in your profile settings to create your public Shelf.'
    end
  end

  def show
    load_collection_context
    load_presentation
    @overview = !@collection && !FavoriteShelf::CATEGORIES.key?(params[:category])
    @category = @overview || @collection ? 'overall' : params[:category]
    @shelves = load_shelves_with_batch_items(@user)
    @items = @collection ? @collection.items : @shelves.find { |shelf| shelf[:key] == @category }[:items]
    @shelves = @shelves.select { |shelf| shelf[:items].any? } unless current_user?(@user)
    @preview_category = preview_category
    @preview_signature = helpers.shelf_preview_signature(@user, @preview_category)
    @preview_image = helpers.shelf_preview_image(@user, @preview_category, @theme, style: @image_style)
    render layout: 'shelf'
  end

  def update
    return head :forbidden unless current_user?(@user)

    return create_collection if params.key?(:new_collection)

    @collection = @user.shelf_collections.find_by!(slug: params[:collection]) if params[:collection].present?
    return update_collection if @collection && !params.key?(:preview_image)

    return update_presentation if params.key?(:presentation)

    return update_preview if params.key?(:preview_image)

    return update_headline if params.key?(:shelf_headline)

    update_picks
  end

  def search
    types = FavoriteShelf::CATEGORIES.keys - ['overall']
    types &= [params[:category]] unless params[:category] == 'overall'
    query = params[:q].to_s.strip.first(100)
    return render json: [] if query.length < 2

    matches = types.flat_map do |type|
      MetadataSearch.call(type.constantize.with_attached_cover_image, query)
                    .order(:title).limit(8).map do |item|
        { id: item.id, type: type, title: item.title,
          year: item.respond_to?(:release_year) ? item.release_year : nil,
          url: polymorphic_path(item), cover: item.respond_to?(:stored_cover_url) ? item.stored_cover_url : nil }
      end
    end
    render json: matches.first(30)
  end

  private

  def load_collection_context
    @collection = @user.shelf_collections.find_by!(slug: params[:collection]) if params[:collection].present?
    @collections = @user.shelf_collections.order(:created_at)
    @collections = @collections.select { |collection| collection.items.any? } unless current_user?(@user)
  end

  def load_presentation
    presentation = (@collection ? @collection.presentation : @user.shelf_presentation).presence || params
    @theme = ShelvesHelper::SHELF_THEMES.include?(presentation['theme']) ? presentation['theme'] : 'midnight'
    @image_style = helpers.shelf_image_style(presentation)
  end

  def preview_category
    return "collection:#{@collection.slug}" if @collection

    @overview ? 'overview' : @category
  end

  def update_picks
    shelf = @user.favorite_shelves.find_or_initialize_by(category: params[:category])
    input = params[:picks]
    unless input.is_a?(Array) && input.all? { |pick| pick.respond_to?(:permit) }
      return render json: { error: 'Choose up to five picks.' }, status: :unprocessable_content
    end

    shelf.picks = input.map { |pick| { 'type' => pick[:type], 'id' => pick[:id].to_i } }
    if shelf.save
      render json: { saved: true, preview_signature: helpers.shelf_preview_signature(@user, shelf.category) }
    else
      render json: { error: shelf.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  def create_collection
    collection = @user.shelf_collections.new(params.require(:new_collection).permit(:title, :description))
    if collection.save
      redirect_to shelf_path(@user.username, collection: collection.slug), status: :see_other
    else
      redirect_to shelf_path(@user.username), alert: collection.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def update_collection
    if params.key?(:presentation)
      input = params[:presentation]
      return head :unprocessable_content unless input.respond_to?(:permit) &&
                                                ShelvesHelper::SHELF_THEMES.include?(input[:theme])

      @collection.presentation = helpers.shelf_image_style(input).merge('theme' => input[:theme])
    else
      input = params[:picks]
      return head :unprocessable_content unless input.is_a?(Array) && input.all? { |pick| pick.respond_to?(:permit) }

      @collection.picks = input.map { |pick| { 'type' => pick[:type], 'id' => pick[:id].to_i } }
    end
    if @collection.save
      render json: { saved: true,
                     preview_signature: helpers.shelf_preview_signature(@user, "collection:#{@collection.slug}") }
    else
      render json: { error: @collection.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end

  def update_presentation
    input = params[:presentation]
    return head :unprocessable_content unless input.respond_to?(:permit) &&
                                              ShelvesHelper::SHELF_THEMES.include?(input[:theme])

    @user.update!(shelf_presentation: helpers.shelf_image_style(input).merge('theme' => input[:theme]))
    render json: { saved: true }
  end

  def update_preview
    category = params[:preview_category].to_s
    theme = params[:theme].to_s
    style = helpers.shelf_image_style(params)
    image = params[:preview_image]
    return head :unprocessable_content unless valid_preview_upload?(image, category, theme)

    image.rewind
    signature = helpers.shelf_preview_signature(@user, category)
    return head :conflict unless params[:preview_signature] == signature

    @user.with_lock do
      return head :conflict unless params[:preview_signature] == helpers.shelf_preview_signature(@user, category)
      return head :no_content if helpers.shelf_preview_image(@user, category, theme, style: style)

      persist_preview(image, category, theme, signature, style)
    end
    head :no_content
  end

  def valid_preview_upload?(image, category, theme)
    valid_category = FavoriteShelf::CATEGORIES.key?(category) || category == 'overview' ||
                     (category.start_with?('collection:') &&
                      @user.shelf_collections.exists?(slug: category.delete_prefix('collection:')))
    valid_category &&
      ShelvesHelper::SHELF_THEMES.include?(theme) &&
      image.is_a?(ActionDispatch::Http::UploadedFile) && image.content_type == 'image/png' &&
      image.size <= 5.megabytes && image.read(8) == "\x89PNG\r\n\x1a\n".b
  end

  def persist_preview(image, category, theme, signature, style)
    previous = @user.shelf_previews.select do |preview|
      preview.blob.metadata.values_at('category', 'theme') == [category, theme]
    end
    @user.shelf_previews.attach(io: image.tempfile, filename: 'shelf.png', content_type: 'image/png',
                                metadata: { category: category, theme: theme, signature: signature, style: style })
    previous.each(&:purge_later)
  end

  def update_headline
    headline = params[:shelf_headline]
    return head :unprocessable_content unless headline.is_a?(String)

    if @user.update(shelf_headline: headline.strip.presence)
      redirect_to shelf_path(@user.username, theme: params[:theme]), notice: 'Shelf headline saved.', status: :see_other
    else
      redirect_to shelf_path(@user.username, theme: params[:theme]), alert: @user.errors.full_messages.to_sentence,
                                                                     status: :see_other
    end
  end

  def load_user
    @user = User.where('LOWER(username) = ?', params[:username].to_s.downcase).first!
  end

  # Batch preloads all pick items across all user favorite shelves grouped by media type,
  # reducing N+1 queries from up to 35+ queries down to 1 query per media type.
  def load_shelves_with_batch_items(user)
    shelves_by_cat = user.favorite_shelves.index_by(&:category)
    records_by_type = fetch_records_by_type(shelves_by_cat.values)

    FavoriteShelf::CATEGORIES.map do |key, label|
      shelf = shelves_by_cat[key]
      items = shelf ? resolve_shelf_items(shelf, records_by_type) : []
      { key: key, label: label, items: items }
    end
  end

  def fetch_records_by_type(shelves)
    all_picks = shelves.flat_map { |shelf| Array(shelf.picks) }
    valid_picks = all_picks.select { |p| p.is_a?(Hash) && FavoriteShelf::CATEGORIES.key?(p['type']) && p['type'] != 'overall' }

    valid_picks.group_by { |p| p['type'] }.transform_values do |group|
      ids = group.map { |p| p['id'].to_i }.uniq
      group.first['type'].constantize.where(id: ids).with_attached_cover_image.index_by(&:id)
    end
  end

  def resolve_shelf_items(shelf, records_by_type)
    picks = Array(shelf.picks).select { |p| p.is_a?(Hash) && FavoriteShelf::CATEGORIES.key?(p['type']) && p['type'] != 'overall' }
    picks.filter_map { |p| records_by_type[p['type']]&.[](p['id'].to_i) }
  end
end
