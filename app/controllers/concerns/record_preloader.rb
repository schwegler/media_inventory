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

  def preload_likes_data(records, user = nil)
    return if records.blank?

    entities = collect_likeable_entities(records)
    return if entities.empty?

    @preloaded_likes_counts ||= {}
    @preloaded_user_likes ||= Set.new
    @preloaded_likeable_keys ||= Set.new

    types = entities.map { |e| e.class.base_class.name }.uniq
    ids = entities.map(&:id).uniq

    # 1. Bulk fetch like counts
    Like.where(likeable_type: types, likeable_id: ids)
        .group(:likeable_type, :likeable_id).count.each do |(type, id), count|
      @preloaded_likes_counts["#{type}:#{id}"] = count
    end

    # 2. Bulk fetch current user's likes
    if user
      Like.where(user: user, likeable_type: types, likeable_id: ids)
          .pluck(:likeable_type, :likeable_id).each do |type, id|
        @preloaded_user_likes.add("#{type}:#{id}")
      end
    end

    entities.each { |e| @preloaded_likeable_keys.add("#{e.class.base_class.name}:#{e.id}") }
  end

  # rubocop:disable Metrics/PerceivedComplexity
  def collect_likeable_entities(records)
    entities = []
    records.compact.each do |record|
      entities << record if record.class.reflect_on_association(:likes)

      if record.is_a?(Activity) && record.trackable
        entities << record.trackable if record.trackable.class.reflect_on_association(:likes)
        if record.trackable.is_a?(LibraryItem) && record.trackable.item&.class&.reflect_on_association(:likes)
          entities << record.trackable.item
        end
      elsif record.is_a?(LibraryItem) && record.item&.class&.reflect_on_association(:likes)
        entities << record.item
      end
    end
    entities.uniq
  end
  # rubocop:enable Metrics/PerceivedComplexity
end
# rubocop:enable Metrics/ModuleLength
