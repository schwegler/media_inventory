module Admin
  class EditSuggestionsController < Admin::ApplicationController
    def approve
      edit_suggestion = EditSuggestion.find(params[:id])
      
      if edit_suggestion.status == 'pending'
        suggestable = edit_suggestion.suggestable
        
        changes = edit_suggestion.proposed_changes
        changes = JSON.parse(changes) if changes.is_a?(String)
        
        if suggestable.update(changes)
          edit_suggestion.update(status: 'approved')
          Notification.create!(
            recipient: edit_suggestion.user,
            actor: current_user,
            action: 'approved_edit',
            notifiable: edit_suggestion
          )
          redirect_to admin_edit_suggestion_path(edit_suggestion), notice: 'Edit suggestion approved and applied.'
        else
          redirect_to admin_edit_suggestion_path(edit_suggestion), alert: "Failed to apply changes: #{suggestable.errors.full_messages.join(', ')}"
        end
      else
        redirect_to admin_edit_suggestion_path(edit_suggestion), alert: 'Suggestion is not pending.'
      end
    end

    def reject
      edit_suggestion = EditSuggestion.find(params[:id])
      
      if edit_suggestion.status == 'pending'
        edit_suggestion.update(status: 'rejected')
        Notification.create!(
          recipient: edit_suggestion.user,
          actor: current_user,
          action: 'rejected_edit',
          notifiable: edit_suggestion
        )
        redirect_to admin_edit_suggestion_path(edit_suggestion), notice: 'Edit suggestion rejected.'
      else
        redirect_to admin_edit_suggestion_path(edit_suggestion), alert: 'Suggestion is not pending.'
      end
    end
  end
end
