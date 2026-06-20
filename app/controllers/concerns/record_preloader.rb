# frozen_string_literal: true

module RecordPreloader
  extend ActiveSupport::Concern

  private

  def preload_activities_attachments(activities)
    return activities if activities.blank?

    trackables = activities.map(&:trackable).compact
    preload_records_attachments(trackables)
    activities
  end

  def preload_records_attachments(records)
    return records if records.blank?

    # 1. Handle LibraryItems: preload their polymorphic 'item' association
    library_items = records.select { |r| r.is_a?(LibraryItem) }
    if library_items.any?
      ActiveRecord::Associations::Preloader.new(
        records: library_items,
        associations: :item
      ).call
    end

    # 2. Identify all unique record instances that might have attachments.
    # This includes the records passed in and the 'item' of any LibraryItem.
    all_potential_attachment_holders = (records + library_items.map(&:item)).compact.uniq

    # 3. Group by class and preload cover_image_attachment where applicable.
    all_potential_attachment_holders.group_by(&:class).each do |klass, grouped_records|
      next unless klass.respond_to?(:reflect_on_association) &&
                  klass.reflect_on_association(:cover_image_attachment)

      ActiveRecord::Associations::Preloader.new(
        records: grouped_records,
        associations: { cover_image_attachment: :blob }
      ).call
    end

    records
  end
end
