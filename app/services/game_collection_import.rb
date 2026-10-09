# frozen_string_literal: true

require 'csv'

# Import appends transactionally and resolves only strong existing identities.
# It never performs title-only reconciliation or remote lookups.
class GameCollectionImport
  class Invalid < StandardError; end
  MAX_BYTES = 1.megabyte
  COPY_FIELDS = %w[platform storefront edition ownership_status access_method purchase_date purchase_price currency
                   notes acquisition_source gifted condition region imported_playtime_minutes].freeze
  PLAY_FIELDS = %w[platform status difficulty route progress started_on completed_on notes].freeze
  SESSION_FIELDS = %w[started_at ended_at notes milestones enjoyment mood progress].freeze
  MILESTONE_FIELDS = %w[title description completed_at spoiler].freeze
  COLLECTION_FIELDS = %w[rating review is_collected in_backlog consumed consumed_at owned_physically
                         owned_physically_format owned_digitally owned_digitally_format game_favorite game_tags].freeze

  def self.preview(text, format: 'json')
    raise Invalid, 'Import exceeds 1 MB' if text.bytesize > MAX_BYTES

    data = parse(text, format)
    validate_identity!(data)
    validate_rows!(data)
    validate_content!(data)
    data
  rescue JSON::ParserError, CSV::MalformedCSVError, TypeError, ActiveRecord::UnknownAttributeError
    raise Invalid, 'Malformed import file'
  end

  def self.validate_content!(data)
    data['copies']&.each { |row| validate_record!(GameCopy.new(row.slice(*COPY_FIELDS)), :library_item) }
    data['playthroughs']&.each { |row| validate_playthrough!(row) }
    data['milestones']&.each { |row| validate_record!(GameMilestone.new(row.slice(*MILESTONE_FIELDS)), :library_item) }
    data['journal']&.each do |row|
      raise Invalid, 'Invalid journal entry' if row['body'].blank? || row['body'].to_s.size > 50_000
    end
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

    data['game']['id'] = GameImportIdentity.resolve(data).id
    collection = data['collection'] || {}
    raise Invalid, 'Invalid personal collection data' unless collection.is_a?(Hash)

    validate_collection!(collection)
  end

  def self.validate_collection!(collection)
    rating = collection['rating']
    raise Invalid, 'Rating must be between 0.5 and 5 in half-star steps' if
      rating.present? && !rating.to_s.match?(/\A(?:0\.5|[1-4](?:\.[05])?|5(?:\.0)?)\z/)

    record = LibraryItem.new(collection.slice(*COLLECTION_FIELDS))
    record.valid?
    errors = record.errors.reject { |error| %i[user item].include?(error.attribute) }
    raise Invalid, errors.map(&:full_message).join(', ') if errors.any?
  end

  def self.validate_rows!(data)
    %w[copies playthroughs journal milestones].each do |key|
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
      library = user.library_items.find_or_initialize_by(item: VideoGame.find(data.dig('game', 'id')))
      library.assign_attributes((data['collection'] || {}).slice(*COLLECTION_FIELDS)) if library.new_record?
      library.save!
      Array(data['copies']).each { |row| library.game_copies.find_or_create_by!(row.slice(*COPY_FIELDS)) }
      apply_playthroughs(library, data)
      Array(data['milestones']).each do |row|
        library.game_milestones.find_or_create_by!(row.slice(*MILESTONE_FIELDS))
      end
      Array(data['journal']).each { |row| library.game_journal_entries.find_or_create_by!(row.slice('body', 'spoiler')) }
      library
    end
  end

  def self.apply_playthroughs(library, data)
    Array(data['playthroughs']).each do |row|
      playthrough = library.game_playthroughs.find_or_create_by!(row.slice(*PLAY_FIELDS))
      Array(row['sessions']).each do |session|
        playthrough.game_sessions.find_or_create_by!(session.slice(*SESSION_FIELDS))
      end
    end
  end

  def self.validate_record!(record, association)
    record.valid?
    # Ownership is supplied by the current user's library only during apply.
    errors = record.errors.reject { |error| error.attribute == association }
    raise Invalid, errors.map(&:full_message).join(', ') if errors.any?
  end
end
