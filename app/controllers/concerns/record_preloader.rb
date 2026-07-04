# frozen_string_literal: true

module RecordPreloader
  extend ActiveSupport::Concern

  private

  def preload_social_feed(records)
    return records if records.blank?

    # ⚡ Bolt: Preload current user's likes to avoid N+1 queries in feeds
    preload_current_user_likes(records) if respond_to?(:logged_in?) && logged_in?

    # Group by class to avoid AssociationNotFoundError
    records.compact.group_by(&:class).each do |klass, grouped_records|
      preload_standard_associations(klass, grouped_records)
      preload_class_specific_associations(klass, grouped_records)
    end

    records
  end

  def preload_standard_associations(klass, records)
    associations = %i[user likes comments likeable].select { |a| klass.reflect_on_association(a) }
    return if associations.empty?

    ActiveRecord::Associations::Preloader.new(records: records, associations: associations).call
  end

  def preload_class_specific_associations(klass, records)
    case klass.name
    when 'Like'
      likeables = records.map(&:likeable).compact
      preload_records_attachments(likeables)
    when 'Activity'
      preload_activities_attachments(records)
    end
  end

  def preload_activities_attachments(activities)
    return activities if activities.blank?

    # ⚡ Bolt: Preload trackable and likes to avoid N+1 queries
    ActiveRecord::Associations::Preloader.new(records: activities, associations: %i[trackable likes]).call
    trackables = activities.map(&:trackable).compact

    # Handle LibraryItem proxy pattern
    lib_items, items = trackables.partition { |t| t.is_a?(LibraryItem) }
    if lib_items.any?
      ActiveRecord::Associations::Preloader.new(records: lib_items, associations: :item).call
      items += lib_items.map(&:item).compact
    end

    preload_records_attachments(items)
    activities
  end

  def preload_library_items(library_items)
    return library_items if library_items.blank?

    # 1. Preload the polymorphic 'item' association
    ActiveRecord::Associations::Preloader.new(
      records: library_items,
      associations: :item
    ).call

    # 2. Preload attachments for the items
    items = library_items.map(&:item).compact
    preload_records_attachments(items)

    library_items
  end

  def preload_records_attachments(records)
    return records if records.blank?

    records.group_by(&:class).each do |klass, grouped_records|
      next unless klass.respond_to?(:reflect_on_association)

      associations = []
      associations << { cover_image_attachment: :blob } if klass.reflect_on_association(:cover_image_attachment)
      # ⚡ Bolt: Preload likes to avoid N+1 queries when showing counts
      associations << :likes if klass.reflect_on_association(:likes)

      next if associations.empty?

      ActiveRecord::Associations::Preloader.new(
        records: grouped_records,
        associations: associations
      ).call
    end
    records
  end

  def preload_current_user_likes(records)
    records = records.values if records.is_a?(Hash)
    return if records.blank?

    @preloaded_liked_ids_by_type ||= {}
    to_fetch = collect_likeables(records).reject { |i| already_preloaded?(i) }
    return if to_fetch.empty?

    Like.where(user: current_user, likeable: to_fetch).each do |like|
      (@preloaded_liked_ids_by_type[like.likeable_type] ||= Set.new) << like.likeable_id
    end
    to_fetch.each { |item| @preloaded_liked_ids_by_type[item.class.name] ||= Set.new }
  end

  def collect_likeables(records)
    Array(records).compact.flat_map do |r|
      [r, r.try(:trackable), r.try(:item), r.try(:trackable).try(:item)].compact
    end.uniq
  end

  def already_preloaded?(item)
    @preloaded_liked_ids_by_type[item.class.name]&.include?(item.id)
  end
end
