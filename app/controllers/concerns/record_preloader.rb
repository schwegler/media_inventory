# frozen_string_literal: true

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

    # ⚡ Bolt: Preload likes data to avoid N+1 queries in views
    # Must be done AFTER associations are preloaded to avoid N+1 during collection
    preload_likes_data(records)

    records
  end

  def preload_likes_data(records)
    return records if records.blank?

    likeables = collect_likeable_entities(records)
    return records if likeables.empty?

    initialize_likes_caches(likeables)
    records
  end

  def collect_likeable_entities(records) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    entities = Set.new
    records.compact.each do |record|
      add_if_likeable(entities, record)

      # ⚡ Bolt: Safely traverse preloaded associations to gather likeable entities
      if record.respond_to?(:trackable) && record.association(:trackable).loaded?
        trackable = record.trackable
        add_if_likeable(entities, trackable)
        if trackable.is_a?(LibraryItem) && trackable.association(:item).loaded?
          add_if_likeable(entities, trackable.item)
        end
      elsif record.is_a?(LibraryItem) && record.association(:item).loaded?
        add_if_likeable(entities, record.item)
      elsif record.is_a?(Like) && record.association(:likeable).loaded?
        add_if_likeable(entities, record.likeable)
      end
    end
    entities.to_a.compact
  end

  def add_if_likeable(set, record)
    return if record.nil?

    set << record if record.class.respond_to?(:reflect_on_association) && record.class.reflect_on_association(:likes)
  end

  def initialize_likes_caches(likeables)
    @preloaded_likes_counts ||= {}
    @preloaded_liked_ids_by_type ||= {}

    # Fetch counts for all likeables in one query
    counts = Like.where(likeable: likeables).group(:likeable_type, :likeable_id).count
    counts.each do |(type, id), count|
      @preloaded_likes_counts["#{type}_#{id}"] = count
    end

    # Fetch which items the current user has liked in one query
    return unless logged_in?

    liked_ids = Like.where(user: current_user, likeable: likeables)
                    .pluck(:likeable_type, :likeable_id)
    liked_ids.each do |type, id|
      (@preloaded_liked_ids_by_type[type] ||= Set.new) << id
    end
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

    # ⚡ Bolt: Preload likes data after items are loaded
    preload_likes_data(library_items)

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
