# frozen_string_literal: true

module Admin
  class ModerateSuggestion
    ALLOWED_FIELDS = %w[title name director artist author writer publisher developer platform release_year
                        genre network api_id external_url thumbnail_url issue_number summary].freeze
    class InvalidDecision < StandardError; end

    def initialize(suggestion, actor)
      @suggestion = suggestion
      @actor = actor
    end

    def call(decision)
      raise InvalidDecision, 'Unknown review decision.' unless %w[approved rejected].include?(decision)

      @suggestion.with_lock do
        raise InvalidDecision, 'Suggestion is not pending.' unless @suggestion.status == 'pending'

        apply_changes! if decision == 'approved'
        @suggestion.update!(status: decision)
        Notification.create!(recipient: @suggestion.user, actor: @actor,
                             action: "#{decision}_edit", notifiable: @suggestion)
      end
    end

    private

    def validate_links!(changes)
      %w[external_url thumbnail_url].each do |field|
        next if changes[field].blank?

        reference = URI.parse(changes[field].to_s)
        next if %w[http https].include?(reference.scheme) && reference.host.present?

        raise InvalidDecision, 'Proposed links must be valid HTTP or HTTPS URLs.'
      end
    rescue URI::InvalidURIError
      raise InvalidDecision, 'Proposed links must be valid HTTP or HTTPS URLs.'
    end

    def apply_changes!
      media = @suggestion.suggestable
      raise InvalidDecision, 'The affected media record no longer exists.' unless media

      changes = @suggestion.proposed_changes
      changes = JSON.parse(changes) if changes.is_a?(String)
      unless changes.is_a?(Hash) && changes.keys.all? { |key| ALLOWED_FIELDS.include?(key) && media.has_attribute?(key) }
        raise InvalidDecision, 'This suggestion includes unsupported fields. Review the record manually.'
      end

      validate_links!(changes)
      media.with_lock { media.update!(changes) }
    rescue JSON::ParserError
      raise InvalidDecision, 'The proposed changes could not be read. Review the record manually.'
    end
  end
end
