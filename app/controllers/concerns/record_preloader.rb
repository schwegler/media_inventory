# frozen_string_literal: true

module RecordPreloader
  extend ActiveSupport::Concern

  # Bulk-preloads like counts and current user's liked status for a collection of records.
  # This eliminates N+1 queries when rendering list of items that have like buttons.
  def preload_likes_data(records)
    return if records.blank?

    @preloaded_likes_counts ||= {}
    @preloaded_liked_keys ||= Set.new
    @preloaded_likeable_keys ||= Set.new

    likeables = []
    records.each do |record|
      next if record.nil?

      likeables << record

      if record.respond_to?(:trackable) && record.trackable.present?
        likeables << record.trackable
        if record.trackable.is_a?(LibraryItem) && record.trackable.item.present?
          likeables << record.trackable.item
        end
      end

      if record.respond_to?(:item) && record.item.present?
        likeables << record.item
      end

      if record.respond_to?(:comments) && record.association(:comments).loaded?
        likeables.concat(record.comments)
      end
    end

    likeables = likeables.uniq.compact
    return if likeables.empty?

    new_likeables = likeables.reject do |item|
      key = "#{item.class.base_class.name}_#{item.id}"
      @preloaded_likeable_keys.include?(key)
    end

    return if new_likeables.empty?

    new_likeables.each do |item|
      key = "#{item.class.base_class.name}_#{item.id}"
      @preloaded_likeable_keys.add(key)
    end

    by_class = new_likeables.group_by { |item| item.class.base_class.name }
    likes_query = nil
    by_class.each do |klass_name, items|
      ids = items.map(&:id)
      sub_query = Like.where(likeable_type: klass_name, likeable_id: ids)
      likes_query = likes_query ? likes_query.or(sub_query) : sub_query
    end

    return if likes_query.nil?

    # Calculate counts
    counts = likes_query.group(:likeable_type, :likeable_id).count
    counts.each do |(type, id), count|
      @preloaded_likes_counts["#{type}_#{id}"] = count
    end

    # Calculate current user liked status if logged in
    controller_ctx = respond_to?(:helpers) ? self : (respond_to?(:controller) ? controller : nil)
    is_logged_in = false
    cur_user = nil

    if controller_ctx
      is_logged_in = controller_ctx.send(:logged_in?) if controller_ctx.respond_to?(:logged_in?, true)
      cur_user = controller_ctx.send(:current_user) if controller_ctx.respond_to?(:current_user, true)
    else
      is_logged_in = logged_in? if respond_to?(:logged_in?)
      cur_user = current_user if respond_to?(:current_user)
    end

    if is_logged_in && cur_user.present?
      user_likes = likes_query.where(user_id: cur_user.id).pluck(:likeable_type, :likeable_id)
      user_likes.each do |type, id|
        @preloaded_liked_keys.add("#{type}_#{id}")
      end
    end
  end

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
end
