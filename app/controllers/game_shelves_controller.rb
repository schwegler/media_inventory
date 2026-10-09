# frozen_string_literal: true

class GameShelvesController < ApplicationController
  helper VideoGamesHelper

  def show
    @user = User.find_by_profile_param!(params[:user_id])
    return if redirect_to_canonical_url(@user, param: :user_id, path: game_shelf_path(@user))

    scope = @user.library_items.where(item_type: 'VideoGame', is_public: true, game_activity_public: true)
    scope = scope.none unless @user.confirmed_at.present?
    scope = scope.where(game_favorite: true) if params[:favorites] == '1'
    if GamePlaythrough::STATUSES.include?(params[:status])
      runs = GamePlaythrough.where(library_item_id: scope.select(:id), status: params[:status])
      scope = scope.where(id: runs.select(:library_item_id))
    end
    @games = scope.includes(:game_playthroughs,
                            game_cover_image_attachment: { blob: { artwork_renditions: :blob } },
                            item: { cover_image_attachment: { blob: { artwork_renditions: :blob } } })
                  .order(game_favorite: :desc, created_at: :desc)
                  .page(params[:page])
  end
end
