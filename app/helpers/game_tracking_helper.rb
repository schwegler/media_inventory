# frozen_string_literal: true

module GameTrackingHelper
  def tracking_modal_title(kind, action)
    is_new = action.to_s == 'new'
    case kind.to_s
    when 'copy'
      is_new ? 'Add Game Copy' : 'Edit Game Copy'
    when 'playthrough'
      is_new ? 'Start Playthrough' : 'Edit Playthrough'
    when 'session'
      is_new ? 'Record Play Session' : 'Edit Play Session'
    when 'milestone'
      is_new ? 'Add Milestone' : 'Edit Milestone'
    else
      is_new ? 'New Journal Entry' : 'Edit Journal Entry'
    end
  end
end
