# frozen_string_literal: true

class GameLibraryViewsController < ApplicationController
  before_action :logged_in_user

  def create
    return redirect_to video_games_path(library: 'mine'), alert: 'You can save up to 20 views.' if
      current_user.game_library_views.count >= 20

    view = current_user.game_library_views.new(name: params[:name].to_s.strip,
                                               filters: GameLibraryQuery.normalize(params.fetch(:filters, {})))
    if view.save
      redirect_to video_games_path(library: 'mine', view: view.id), notice: 'Collection view saved.', status: :see_other
    else
      redirect_to video_games_path(library: 'mine'), alert: view.errors.full_messages.join(', '), status: :see_other
    end
  end

  def destroy
    current_user.game_library_views.find(params[:id]).destroy!
    redirect_to video_games_path(library: 'mine'), notice: 'Saved view removed.', status: :see_other
  end
end
