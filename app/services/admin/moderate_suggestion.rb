# frozen_string_literal: true

module Admin
  class ModerateSuggestion
    ALLOWED_FIELDS = %w[title name director artist author writer actors publisher developer platform release_year
                        genre network api_id external_url thumbnail_url issue_number summary synopsis game_type
                        metadata_details].freeze
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

    def normalize_details(media, changes)
      return [changes, []] unless changes.key?('metadata_details')

      current = media.metadata_details
      proposed = MetadataDetailFields.normalize(changes['metadata_details'], current)
      changed = proposed.reject { |key, value| current[key] == value }
      [changes.merge('metadata_details' => current.merge(proposed)), changed.keys]
    rescue ArgumentError, TypeError
      raise InvalidDecision, 'Provider detail corrections must use supported fields and valid values.'
    end

    def protect_credit_corrections(media, changes, detail_keys)
      return unless media.respond_to?(:metadata_credits_data)

      media.metadata_credits_data = MetadataEntitySync.without_corrected_roles(
        media, media.metadata_credits_data, changes.keys, detail_keys
      )
    end

    def proposed_changes(media)
      changes = @suggestion.proposed_changes
      changes = JSON.parse(changes) if changes.is_a?(String)
      unless changes.is_a?(Hash) && changes.keys.all? { |key| ALLOWED_FIELDS.include?(key) && media.has_attribute?(key) }
        raise InvalidDecision, 'This suggestion includes unsupported fields. Review the record manually.'
      end

      validate_links!(changes)
      changes
    end

    def apply_changes!
      media = @suggestion.suggestable
      raise InvalidDecision, 'The affected media record no longer exists.' unless media

      changes = proposed_changes(media)
      media.with_lock do
        changes, detail_keys = normalize_details(media, changes)
        changes = changes.reject { |field, value| media.public_send(field).to_s == value.to_s }
        protect_credit_corrections(media, changes, detail_keys)
        media.importing_metadata = true if media.respond_to?(:importing_metadata=)
        media.refreshing_metadata = true if media.respond_to?(:refreshing_metadata=)
        media.update!(changes)
        refresh = MetadataRefresh.find_or_create_by!(item: media)
        corrected = Array(refresh.provider_values['corrected_fields']) | (changes.keys - ['metadata_details'])
        detail_keys |= Array(refresh.provider_values['corrected_detail_fields'])
        refresh.update!(provider_values: refresh.provider_values.merge('corrected_fields' => corrected,
                                                                       'corrected_detail_fields' => detail_keys))
      end
    rescue JSON::ParserError
      raise InvalidDecision, 'The proposed changes could not be read. Review the record manually.'
    end
  end
end
