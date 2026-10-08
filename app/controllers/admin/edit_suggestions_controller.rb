# frozen_string_literal: true

module Admin
  class EditSuggestionsController < ApplicationController
    def show
      @next_pending = EditSuggestion.where(status: 'pending').where.not(id: params[:id]).order(:created_at).first
      super
    end

    def approve
      moderate('approved')
    end

    def reject
      moderate('rejected')
    end

    private

    def resource_params
      permitted = super
      return permitted unless action_name == 'create' && permitted[:proposed_changes].is_a?(String)

      permitted[:proposed_changes] = JSON.parse(permitted[:proposed_changes])
      permitted
    rescue JSON::ParserError
      permitted[:proposed_changes] = nil
      permitted
    end

    def moderate(decision)
      suggestion = requested_resource
      ModerateSuggestion.new(suggestion, current_user).call(decision)
      message = decision == 'approved' ? 'Edit suggestion approved and applied.' : 'Edit suggestion rejected.'
      redirect_to admin_edit_suggestion_path(suggestion), notice: message, status: :see_other
    rescue ModerateSuggestion::InvalidDecision => e
      redirect_to admin_edit_suggestion_path(suggestion), alert: e.message, status: :see_other
    rescue ActiveRecord::RecordInvalid
      redirect_to admin_edit_suggestion_path(suggestion),
                  alert: 'The decision could not be saved. Check the proposed values and try again.', status: :see_other
    end
  end
end
