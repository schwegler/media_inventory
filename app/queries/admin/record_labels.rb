# frozen_string_literal: true

module Admin
  module RecordLabels
    def self.preload(records)
      records.group_by(&:class).each do |model, group|
        association = { 'LibraryItem' => :item, 'TvEpisode' => :tv_show, 'ComicIssue' => :comic }[model.name]
        next unless association

        ActiveRecord::Associations::Preloader.new(records: group, associations: association).call
        preload(group.filter_map(&:item)) if model == LibraryItem
      end
    end
  end
end
