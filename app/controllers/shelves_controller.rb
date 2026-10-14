# frozen_string_literal: true

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
    @overview = !FavoriteShelf::CATEGORIES.key?(params[:category])
    @theme = %w[midnight gallery electric].include?(params[:theme]) ? params[:theme] : 'midnight'
    @category = @overview ? 'overall' : params[:category]
    saved = @user.favorite_shelves.index_by(&:category)
    @shelves = FavoriteShelf::CATEGORIES.map do |key, label|
      { key: key, label: label, items: saved[key]&.items || [] }
    end
    @items = @shelves.find { |shelf| shelf[:key] == @category }[:items]
    @preview_category = @overview ? 'overview' : @category
    @preview_signature = helpers.shelf_preview_signature(@user, @preview_category)
    @preview_image = helpers.shelf_preview_image(@user, @preview_category, @theme)
    render layout: 'shelf'
  end

  def update
    return head :forbidden unless current_user?(@user)

    return update_preview if params.key?(:preview_image)

    return update_headline if params.key?(:shelf_headline)

    shelf = @user.favorite_shelves.find_or_initialize_by(category: params[:category])
    input = params[:picks]
    unless input.is_a?(Array) && input.all? { |pick| pick.respond_to?(:permit) }
      return render json: { error: 'Choose up to five favorites.' }, status: :unprocessable_content
    end

    shelf.picks = input.map { |pick| { 'type' => pick[:type], 'id' => pick[:id].to_i } }
    if shelf.save
      render json: { saved: true, preview_signature: helpers.shelf_preview_signature(@user, shelf.category) }
    else
      render json: { error: shelf.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
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

  def update_preview
    category = params[:preview_category].to_s
    theme = params[:theme].to_s
    image = params[:preview_image]
    unless (FavoriteShelf::CATEGORIES.key?(category) || category == 'overview') &&
           %w[midnight gallery electric].include?(theme) &&
           image.is_a?(ActionDispatch::Http::UploadedFile) && image.content_type == 'image/png' &&
           image.size <= 5.megabytes && image.read(8) == "\x89PNG\r\n\x1a\n".b
      return head :unprocessable_content
    end

    image.rewind
    signature = helpers.shelf_preview_signature(@user, category)
    return head :conflict unless params[:preview_signature] == signature

    previous = @user.shelf_previews.select do |preview|
      preview.blob.metadata.values_at('category', 'theme') == [category, theme]
    end
    @user.shelf_previews.attach(io: image.tempfile, filename: 'shelf.png', content_type: 'image/png',
                                metadata: { category: category, theme: theme, signature: signature })
    previous.each(&:purge_later)
    head :no_content
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
end
