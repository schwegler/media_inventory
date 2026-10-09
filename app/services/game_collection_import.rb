# frozen_string_literal: true

require 'csv'

# Import is append-only, transactionally applied, and requires explicit canonical
# IDs from our own export. No title-only reconciliation or remote lookups occur.
class GameCollectionImport
  class Invalid < StandardError; end
  MAX_BYTES = 1.megabyte
  COPY_FIELDS = %w[platform storefront edition ownership_status access_method purchase_date purchase_price currency
                   notes].freeze
  PLAY_FIELDS = %w[platform status difficulty route progress started_on completed_on notes].freeze
  SESSION_FIELDS = %w[started_at ended_at notes milestones].freeze

  def self.preview(text, format: 'json')
    raise Invalid, 'Import exceeds 1 MB' if text.bytesize > MAX_BYTES

    data = parse(text, format)
    validate_identity!(data)
    validate_rows!(data)
    data['copies']&.each { |row| validate_record!(GameCopy.new(row.slice(*COPY_FIELDS)), :library_item) }
    data['playthroughs']&.each { |row| validate_playthrough!(row) }
    data['journal']&.each do |row|
      raise Invalid, 'Invalid journal entry' if row['body'].blank? || row['body'].to_s.size > 50_000
    end
    data
  rescue JSON::ParserError, CSV::MalformedCSVError, TypeError, ActiveRecord::UnknownAttributeError
    raise Invalid, 'Malformed import file'
  end

  def self.parse(text, format)
    return JSON.parse(text) unless format == 'csv'

    rows = CSV.parse(text, headers: true).map(&:to_h)
    ids = rows.map { |row| row['game_id'] }.uniq
    raise Invalid, 'CSV must contain copies for one canonical game_id' unless ids.size == 1

    { 'version' => 1, 'game' => { 'id' => ids.first }, 'copies' => rows.map { |row| row.slice(*COPY_FIELDS) } }
  end

  def self.validate_identity!(data)
    raise Invalid, 'Unsupported import version' unless data.is_a?(Hash) && data['version'] == 1

    id = data.dig('game', 'id').to_s
    raise Invalid, 'A valid canonical game ID is required' unless id.match?(/\A\d+\z/)
    raise Invalid, 'Canonical game no longer exists; reconcile identifiers before importing' unless VideoGame.exists?(id)
  end

  def self.validate_rows!(data)
    %w[copies playthroughs journal].each do |key|
      rows = data[key] || []
      raise Invalid, "Invalid #{key}" unless rows.is_a?(Array) && rows.size <= 500 && rows.all?(Hash)
    end
  end

  def self.validate_playthrough!(row)
    validate_record!(GamePlaythrough.new(row.slice(*PLAY_FIELDS)), :library_item)
    sessions = row['sessions'] || []
    raise Invalid, 'Invalid sessions' unless sessions.is_a?(Array) && sessions.size <= 500

    sessions.each do |session|
      raise Invalid, 'Invalid session' unless session.is_a?(Hash)

      validate_record!(GameSession.new(session.slice(*SESSION_FIELDS)), :game_playthrough)
    end
  end

  def self.apply(user, data)
    user.with_lock do
      library = user.library_items.find_or_create_by!(item: VideoGame.find(data.dig('game', 'id')))
      Array(data['copies']).each { |row| library.game_copies.find_or_create_by!(row.slice(*COPY_FIELDS)) }
      Array(data['playthroughs']).each do |row|
        playthrough = library.game_playthroughs.find_or_create_by!(row.slice(*PLAY_FIELDS))
        Array(row['sessions']).each do |session|
          playthrough.game_sessions.find_or_create_by!(session.slice(*SESSION_FIELDS))
        end
      end
      Array(data['journal']).each { |row| library.game_journal_entries.find_or_create_by!(row.slice('body', 'spoiler')) }
      library
    end
  end

  def self.validate_record!(record, association)
    record.valid?
    # Ownership is supplied by the current user's library only during apply.
    errors = record.errors.reject { |error| error.attribute == association }
    raise Invalid, errors.map(&:full_message).join(', ') if errors.any?
  end
end
