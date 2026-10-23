# frozen_string_literal: true

module MetadataEntitiesHelper
  PROVIDER_FIELDS = MetadataDetailFields::LABELS

  def provider_display_details(item)
    return {} unless item.respond_to?(:metadata_details)

    fields = if item.is_a?(VideoGame)
               PROVIDER_FIELDS.slice('original_release_date', 'release_date_label', 'official_website')
             else
               PROVIDER_FIELDS
             end
    fields.each_with_object({}) do |(field, label), result|
      value = item.metadata_details[field]
      result[label] = value if value.present? && (value.is_a?(String) || value.is_a?(Numeric) || value.is_a?(Array))
    end
  end

  def metadata_work_link(item)
    return link_to("#{item.album.title} — #{item.title}", album_path(item.album, anchor: "track-#{item.id}")) if
      item.is_a?(AlbumTrack)

    title = item.respond_to?(:display_title) ? item.display_title : item.title
    link_to(title, item)
  end

  def entity_work_link(item)
    if item.is_a?(ComicIssue)
      link_to("##{item.issue_number} · #{item.title.presence || 'Untitled issue'}", item, title: item.display_title)
    elsif item.is_a?(TvEpisode)
      link_to("S#{item.season} · E#{item.episode} · #{item.name}", item, title: item.title)
    else
      metadata_work_link(item)
    end
  end

  def entity_credit_links(credits)
    safe_join(credits.map do |credit|
      link_to(credit.metadata_entity.display_name, metadata_entity_path(credit.metadata_entity),
              class: 'media-category-link', data: { turbo_frame: '_top' })
    end.uniq, ', ')
  end

  def metadata_search_context(item)
    @match_context&.dig(item.class.name, item.id)
  end

  def child_credit_groups(item)
    linked = item.metadata_credits.to_a
    return linked_child_credit_groups(linked) if linked.any?

    raw = item.respond_to?(:credits) ? Array(item.credits) : []
    raw = raw.select { |credit| credit.is_a?(Hash) && credit['name'].present? }
    entities = MetadataCreditEntityLookup.call(raw)
    raw.group_by { |credit| credit['role'].to_s.humanize.presence || 'Contributor' }.transform_values do |credits|
      safe_join(credits.map do |credit|
        child_credit_label(credit['name'], entities[credit], credit['character'])
      end.uniq, ', ')
    end
  end

  def linked_child_credit_groups(linked)
    linked.group_by(&:role).transform_values do |credits|
      safe_join(credits.map do |credit|
        child_credit_label(credit.metadata_entity.display_name, credit.metadata_entity, credit.details['character'])
      end.uniq, ', ')
    end
  end

  def child_credit_label(name, entity, character)
    label = if entity
              link_to(name, metadata_entity_path(entity), data: { turbo_frame: '_top' })
            else
              ERB::Util.html_escape(name)
            end
    character.present? ? safe_join([label, " as #{character}"]) : label
  end
end
