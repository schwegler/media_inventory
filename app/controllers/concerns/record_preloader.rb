# frozen_string_literal: true

require 'set'

module RecordPreloader
  extend ActiveSupport::Concern

  private

  def preload_social_feed(records)
    return records if records.blank?

    # Group by class to avoid AssociationNotFoundError
    records.compact.group_by(&:class).each do |klass, grouped_records|
      preload_standard_associations(klass, grouped_records)
      preload_class_specific_associations(klass, grouped_records)
    end

    records
  end

  def preload_standard_associations(klass, records)
    associations = []
    associations << :user if klass.reflect_on_association(:user)
    associations << :likes if klass.reflect_on_association(:likes)
    associations << :comments if klass.reflect_on_association(:comments)
    associations << :likeable if klass.reflect_on_association(:likeable)

    return if associations.empty?

    ActiveRecord::Associations::Preloader.new(
      records: records,
      associations: associations
    ).call
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

    # 1. Preload trackable
    ActiveRecord::Associations::Preloader.new(
      records: activities,
      associations: :trackable
    ).call

    trackables = activities.map(&:trackable).compact

    # 2. Handle LibraryItem proxy pattern for trackables
    lib_items, items = trackables.partition { |t| t.is_a?(LibraryItem) }

    if lib_items.any?
      ActiveRecord::Associations::Preloader.new(
        records: lib_items,
        associations: :item
      ).call
      items += lib_items.map(&:item).compact
    end

    # 3. Preload attachments for the underlying items
    preload_records_attachments(items)
    activities
  end

  def preload_likes_data(records)
    return records if records.blank?

    # Collect all items that can be liked
    likeable_entities = collect_likeable_entities(records)
    return records if likeable_entities.blank?

    # 1. Bulk-fetch Like counts (ONE Query)
    counts = Like.where(likeable: likeable_entities)
                 .group(:likeable_type, :likeable_id).count

    @preloaded_likes_counts ||= {}
    counts.each do |(type, id), count|
      @preloaded_likes_counts["#{type}:#{id}"] = count
    end

    # 2. Bulk-fetch current user's Likes (ONE Query)
    if logged_in?
      liked_ids = Like.where(user_id: current_user.id, likeable: likeable_entities)
                      .pluck(:likeable_type, :likeable_id)
                      .map { |type, id| "#{type}:#{id}" }

      @preloaded_liked_keys ||= Set.new
      @preloaded_liked_keys.merge(liked_ids)
    end

    # Track which items we've preloaded counts for (to differentiate 0 from nil)
    @preloaded_likeable_keys ||= Set.new
    likeable_entities.each { |item| @preloaded_likeable_keys.add("#{item.class.base_class.name}:#{item.id}") }

    records
  end

  def collect_likeable_entities(records)
    entities = []
    records.each do |record|
      entities << record if record.respond_to?(:likes)
      # Some records (Activities, LibraryItems) proxy to another item
      if record.respond_to?(:trackable)
        trackable = record.association(:trackable).loaded? ? record.trackable : nil
        entities << trackable if trackable
      end
      if record.respond_to?(:item)
        item = record.association(:item).loaded? ? record.item : nil
        entities << item if item
      end
    end
    entities.uniq.compact
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
      next unless klass.respond_to?(:reflect_on_association) && klass.reflect_on_association(:cover_image_attachment)

      ActiveRecord::Associations::Preloader.new(
        records: grouped_records,
        associations: { cover_image_attachment: :blob }
      ).call
    end
    records
  end
end
