# frozen_string_literal: true

class WrestlingEventsController < InventoryController
  private

  def resource_params
    params.require(:wrestling_event).permit(:title, :promotion, :date, :venue)
  end
end
