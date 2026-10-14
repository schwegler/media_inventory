# frozen_string_literal: true

# Builds a per-media-type presentation for catalog cards so each card shows a
# clear primary byline, labelled secondary credits and a compact facts line
# instead of an unlabelled stack of every metadata field.
module MediaCardHelper
  TRAILING_YEAR = /\s*\((\d{4})\)\s*\z/
  NAME_LIMIT = 2

  CardCredit = Struct.new(:label, :value, :full, keyword_init: true)
  CardPresentation = Struct.new(:title, :byline, :credits, :facts, keyword_init: true)

  def media_card_presentation(item)
    raw_title = (item.try(:display_title) || item.try(:title) || item.try(:name) || 'Media').to_s
    title_year = raw_title[TRAILING_YEAR, 1]
    title = title_year ? raw_title.sub(TRAILING_YEAR, '') : raw_title
    year = item.try(:release_year).presence || title_year

    byline, credits, facts = card_fields_for(item)
    facts = [year, *facts].compact_blank.map(&:to_s).uniq

    CardPresentation.new(title: title.presence || raw_title, byline: byline, credits: credits.compact, facts: facts)
  end

  # Shortens "A, B, C, D" to "A, B +2" so long cast/crew lists stay scannable.
  def card_names(value, limit: NAME_LIMIT)
    names = value.to_s.split(/\s*,\s*/).compact_blank
    return value.to_s.strip if names.size <= limit

    "#{names.first(limit).join(', ')} +#{names.size - limit}"
  end

  private

  def card_fields_for(item)
    case item.class.name
    when 'Movie' then movie_card_fields(item)
    when 'TvShow' then tv_show_card_fields(item)
    when 'Book' then [card_credit('By', item.author), [], [item.publisher]]
    when 'Album' then [card_credit('By', item.artist), [], card_genres(item.genre)]
    when 'Comic' then comic_card_fields(item)
    when 'VideoGame' then video_game_card_fields(item)
    else [nil, [], []]
    end
  end

  def movie_card_fields(item)
    [card_credit('Directed by', item.director),
     [card_credit('Written by', distinct_from(item.writer, item.director))],
     card_genres(item.genre)]
  end

  def tv_show_card_fields(item)
    [card_credit('Network', item.network),
     [card_credit('Created by', item.writer)],
     card_genres(item.genre)]
  end

  def comic_card_fields(item)
    issue = item.issue_number.present? ? "##{item.issue_number}" : nil
    [card_credit('Written by', item.writer),
     [card_credit('Art by', distinct_from(item.artist, item.writer))],
     [issue, item.publisher]]
  end

  def video_game_card_fields(item)
    game_type = item.game_type.present? && item.game_type != 'game' ? item.game_type.humanize : nil
    [card_credit('Developer', item.developer),
     [card_credit('Platforms', item.platform)],
     [game_type]]
  end

  def card_credit(label, value)
    return if value.blank?

    CardCredit.new(label: label, value: card_names(value), full: value.to_s.strip)
  end

  def distinct_from(value, other)
    value.present? && value.to_s.strip.casecmp?(other.to_s.strip) ? nil : value
  end

  def card_genres(genre)
    genre.to_s.split(/\s*,\s*/).compact_blank.first(2)
  end
end
