# frozen_string_literal: true

class ComicsController < InventoryController
  private

  def resource_params
    params.require(:comic).permit(:title, :issue_number, :publisher, :writer, :artist, :is_public)
  end
end
