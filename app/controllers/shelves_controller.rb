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
    @category = FavoriteShelf::CATEGORIES.key?(params[:category]) ? params[:category] : 'overall'
    @shelf = @user.favorite_shelves.find_or_initialize_by(category: @category)
    @items = @shelf.items
  end

  def update
    return head :forbidden unless current_user?(@user)

    shelf = @user.favorite_shelves.find_or_initialize_by(category: params[:category])
    input = params[:picks]
    unless input.is_a?(Array) && input.all? { |pick| pick.respond_to?(:permit) }
      return render json: { error: 'Choose up to five favorites.' }, status: :unprocessable_content
    end

    shelf.picks = input.map { |pick| { 'type' => pick[:type], 'id' => pick[:id].to_i } }
    if shelf.save
      render json: { saved: true }
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
      type.constantize.where('LOWER(title) LIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%")
          .order(:title).limit(8).map do |item|
        { id: item.id, type: type, title: item.title,
          year: item.respond_to?(:release_year) ? item.release_year : nil,
          cover: item.respond_to?(:stored_cover_url) ? item.stored_cover_url : nil }
      end
    end
    render json: matches.first(30)
  end

  private

  def load_user
    @user = User.where('LOWER(username) = ?', params[:username].to_s.downcase).first!
  end
end
