# frozen_string_literal: true

# Start, dismiss and resume watch/read-throughs of a TV show or comic.
class ConsumptionPassesController < ApplicationController
  before_action :logged_in_user
  before_action :set_pass, only: %i[dismiss resume]

  def create
    series_lib = current_user.library_items.find_by(item_type: ConsumptionPass::SERIES_TYPES, id: params[:library_item_id])
    return head(:not_found) unless series_lib

    ConsumptionPasses.start(series_lib)
    label = series_lib.item.is_a?(TvShow) ? 're-watch' : 're-read'
    redirect_back fallback_location: series_lib.item, notice: "Started a #{label}."
  end

  def dismiss
    ConsumptionPasses.dismiss(@pass)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove("in_progress_#{@series.class.name.underscore}_#{@series.id}")
      end
      format.html { redirect_back fallback_location: @series, notice: 'Removed from In progress.' }
    end
  end

  def resume
    ConsumptionPasses.resume(@pass.library_item)
    redirect_back fallback_location: @series, notice: 'Back on In progress.'
  end

  private

  def set_pass
    @pass = ConsumptionPass.joins(:library_item).find_by(id: params[:id], library_items: { user_id: current_user.id })
    return head(:not_found) unless @pass

    @series = @pass.library_item.item
  end
end
