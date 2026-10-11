# frozen_string_literal: true

class ReviewsController < ApplicationController
  before_action :logged_in_user
  before_action :load_reviewable

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update
    review_attributes = {
      review: params[:review].presence,
      rating: params[:rating].presence,
      is_public: ActiveModel::Type::Boolean.new.cast(params[:is_public])
    }

    success = if @item.is_a?(TvEpisode) || @item.is_a?(ComicIssue)
                ConsumptionPasses.apply(current_user, @item, @library_item, review_attributes)
              else
                @library_item.assign_attributes(review_attributes)
                @library_item.save
              end

    if success
      SyncSeriesMetadataJob.perform_later(@item) if @item.is_a?(TvEpisode) && @item.thumbnail_url.blank?
      @tv_episode = @item if @item.is_a?(TvEpisode)
      @comic_issue = @item if @item.is_a?(ComicIssue)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: root_path, notice: 'Review updated.' }
      end
    else
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  private

  def load_reviewable
    allowed_types = %w[Movie TvShow TvEpisode Album Comic ComicIssue VideoGame Book]
    item_type = params[:item_type]

    if item_type.present? && allowed_types.include?(item_type)
      @item = item_type.constantize.find(params[:item_id])
      @library_item = LibraryItem.find_or_initialize_by(user: current_user, item: @item)
    elsif params[:id].present?
      @library_item = current_user.library_items.find(params[:id])
      @item = @library_item.item
    else
      redirect_to root_path, alert: 'Invalid review item.'
    end
  end
end
