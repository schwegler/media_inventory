# frozen_string_literal: true

class WrestlingEventsController < InventoryController
  private

  def wrestling_event_params
    params.require(:wrestling_event).permit(:title, :promotion, :date, :venue)
  end

  def resource_params
    wrestling_event_params
  end
end
