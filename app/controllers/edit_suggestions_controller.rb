# frozen_string_literal: true

class EditSuggestionsController < ApplicationController
  before_action :logged_in_user
  before_action :set_suggestable

  def new
    @edit_suggestion = @suggestable.edit_suggestions.new
  end

  def create
    @edit_suggestion = @suggestable.edit_suggestions.new(edit_suggestion_params)
    @edit_suggestion.user = current_user
    @edit_suggestion.status = 'pending'

    if @edit_suggestion.save
      redirect_to polymorphic_path(@suggestable), notice: 'Edit suggestion submitted successfully and is pending review.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_suggestable
    @suggestable = if params[:movie_id]
                     Movie.find(params[:movie_id])
                   elsif params[:tv_show_id]
                     TvShow.find(params[:tv_show_id])
                   elsif params[:comic_id]
                     Comic.find(params[:comic_id])
                   elsif params[:video_game_id]
                     VideoGame.find(params[:video_game_id])
                   elsif params[:album_id]
                     Album.find(params[:album_id])
                   end
  end

  def edit_suggestion_params
    params.require(:edit_suggestion).permit(proposed_changes: {})
  end
end
