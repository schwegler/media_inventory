# frozen_string_literal: true

class ComicsController < InventoryController
  private

  def comic_params
    params.require(:comic).permit(:title, :issue_number, :publisher, :writer, :artist)
  end

  def resource_params
    comic_params
  end
end
