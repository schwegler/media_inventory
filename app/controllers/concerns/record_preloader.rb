# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
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

    preload_likes_data(records)

    records
  end

  def preload_standard_associations(klass, records)
    associations = []
    associations << :user if klass.reflect_on_association(:user)
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

    preload_likes_data(library_items.to_a + items)

    library_items
  end

  def preload_likes_data(records)
    return if records.blank?

    # ⚡ Bolt: Bulk preload likes count and current user's liked status to avoid N+1 queries
    likeables = collect_likeable_entities(records)
    return if likeables.empty?

    # Initialize caches if they don't exist
    @preloaded_likes_counts ||= {}
    @preloaded_liked_ids_by_type ||= {}

    # 1. Bulk fetch counts
    Like.where(likeable: likeables).group(:likeable_type, :likeable_id).count.each do |(type, id), count|
      @preloaded_likes_counts["#{type}_#{id}"] = count
    end

    # 2. Bulk fetch current user's likes
    return unless logged_in?

    current_user.likes.where(likeable: likeables).pluck(:likeable_type, :likeable_id).each do |type, id|
      (@preloaded_liked_ids_by_type[type] ||= Set.new) << id
    end
  end

  def collect_likeable_entities(records)
    entities = []
    records.each do |record|
      next if record.nil?

      entities << record if record.class.reflect_on_association(:likes)
      entities += extract_nested_likeables(record)
    end
    entities.uniq
  end

  def extract_nested_likeables(record)
    nested = []
    if record.respond_to?(:trackable) && record.trackable
      nested << record.trackable if record.trackable.class.reflect_on_association(:likes)
      if record.trackable.respond_to?(:item) && record.trackable.item&.class&.reflect_on_association(:likes)
        nested << record.trackable.item
      end
    end

    if record.respond_to?(:item) && record.item&.class&.reflect_on_association(:likes)
      nested << record.item
    end
    nested
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
# rubocop:enable Metrics/ModuleLength
