# frozen_string_literal: true

class OrderedChildrenController < ApplicationController
  def show
    response.headers['Cache-Control'] = 'private, no-store'
    @child = controller_name == 'album_tracks' ? AlbumTrack.find(params[:id]) : BookChapter.find(params[:id])
    @parent = OrderedReviewChildren.parent(@child)
    return head :not_found unless @parent

    @library_item = current_user&.library_items&.find_by(item: @child)
  end
end
