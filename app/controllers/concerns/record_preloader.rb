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

    records
  end

  def preload_standard_associations(klass, records)
    associations = []
    # Always include avatar when preloading user to avoid N+1s in feeds
    associations << { user: { avatar_attachment: :blob } } if klass.reflect_on_association(:user)
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
end
