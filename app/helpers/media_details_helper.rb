# frozen_string_literal: true

module MediaDetailsHelper
  CREATOR_ATTRIBUTES = %i[director writer author artist developer].freeze
  TAXONOMY_LABELS = %w[Genre Genres Features Tags Subjects].freeze

  # Catalog data only. Viewer-specific library state never enters this block.
  def media_detail_groups(item)
    rows = media_metadata(item).map do |label, value, attribute|
      [metadata_group(item, attribute), label, render_media_metadata_value(item, attribute, value)]
    end
    rows.concat(extra_credit_rows(item))
    rows.concat(provider_metadata_rows(item))
    rows.concat(game_metadata_rows(item)) if item.is_a?(VideoGame)
    groups = rows.uniq.group_by(&:first)
    %w[details cast creators taxonomy].filter_map do |key|
      next if groups[key].blank?

      { id: "metadata-#{key}", label: metadata_group_label(item, key, groups[key]), rows: groups[key] }
    end
  end

  def metadata_group(item, attribute)
    return 'cast' if attribute == :actors && %w[Movie TvShow].include?(item.class.name)
    return 'creators' if CREATOR_ATTRIBUTES.include?(attribute)
    return 'taxonomy' if attribute == :genre

    'details'
  end

  def metadata_group_label(item, key, rows)
    return %w[Movie TvShow].include?(item.class.name) ? 'Crew' : 'Creators' if key == 'creators'
    return rows.map { |_, label, _| label == 'Genre' ? 'Genres' : label }.uniq.join(' & ') if key == 'taxonomy'

    key.capitalize
  end

  def extra_credit_rows(item)
    displayed = media_metadata(item).filter_map { |_, _, attr| MetadataEntitySync::FIELDS.fetch(item.class.name, {})[attr] }
    displayed << 'Genre' if item.is_a?(VideoGame) && item.metadata_details['genres'].present?
    item.metadata_credits.reject { |credit| displayed.include?(credit.role) }
        .sort_by { |credit| [credit.position, credit.id] }.group_by(&:role).map do |role, credits|
      group = credit_metadata_group(item, role)
      [group, role, entity_credit_links(credits)]
    end
  end

  def credit_metadata_group(item, role)
    return 'cast' if role == 'Actor' && %w[Movie TvShow].include?(item.class.name)
    return 'taxonomy' if role == 'Genre'
    return 'details' if %w[Platform Network].include?(role)

    'creators'
  end

  def provider_metadata_rows(item)
    synopsis = strip_tags(media_synopsis(item).to_s).squish
    provider_display_details(item).filter_map do |label, value|
      next if value.is_a?(Array) && value.compact_blank.empty?
      next if %w[Synopsis Description].include?(label) && strip_tags(value.to_s).squish == synopsis

      group = TAXONOMY_LABELS.include?(label) ? 'taxonomy' : 'details'
      [group, label, value.is_a?(Array) ? value.compact_blank.join(', ') : value]
    end
  end

  def game_metadata_rows(item)
    fields = { 'genres' => 'Genres', 'features' => 'Features', 'tags' => 'Tags',
               'controller_support' => 'Controller support', 'languages' => 'Languages' }
    fields.filter_map do |key, label|
      value = item.metadata_details[key]
      next if value.blank? || (value.is_a?(Array) && value.compact_blank.empty?)

      group = TAXONOMY_LABELS.include?(label) ? 'taxonomy' : 'details'
      [group, label, game_metadata_value(key, value)]
    end
  end

  def game_metadata_value(key, value)
    if value.is_a?(Array)
      tags = value.compact_blank.map do |entry|
        content_tag(:li) do
          if key == 'genres'
            link_to entry, category_item_path(category_type: 'genres', name: entry), class: 'category-pill'
          else
            content_tag(:span, entry, class: 'category-pill-static')
          end
        end
      end
      content_tag(:ul, safe_join(tags), class: 'media-description-tags', role: 'list')
    elsif key == 'languages'
      languages = strip_tags(value.to_s).split(/\*\s*languages with full audio support/i, 2).first.to_s.strip
      note = content_tag(:small, '* Full audio support') if languages.include?('*')
      content_tag(:details, class: 'media-description-disclosure') do
        safe_join([content_tag(:summary, 'Supported languages'), content_tag(:p, languages), note].compact)
      end
    else
      key == 'controller_support' ? value.to_s.humanize : value
    end
  end
end
