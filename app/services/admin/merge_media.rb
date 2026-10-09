# frozen_string_literal: true

module Admin
  class MergeMedia
    class Conflict < StandardError; end

    def self.call(source, target)
      new(source, target).call
    end

    def initialize(source, target)
      @source = source
      @target = target
    end

    def call
      raise Conflict, 'Choose a different record as the merge target.' if @source == @target
      raise Conflict, 'The target must have the same media type.' unless @source.instance_of?(@target.class)

      @source.class.transaction do
        @source.class.where(id: [@source.id, @target.id]).order(:id).lock.load
        transfer_children!
        transfer_polymorphic(LibraryItem, :item)
        transfer_polymorphic(Activity, :trackable)
        transfer_polymorphic(Comment, :commentable)
        transfer_polymorphic(EditSuggestion, :suggestable)
        transfer_likes
        @source.destroy!
      end
    end

    private

    def transfer_polymorphic(model, association)
      model.where(association => @source).update_all("#{association}_id" => @target.id)
    end

    def transfer_likes
      likes = Like.where(likeable: @source)
      likes.where(user_id: Like.where(likeable: @target).select(:user_id)).destroy_all
      likes.update_all(likeable_id: @target.id)
    end

    def transfer_children!
      case @source
      when TvShow then move_children(TvEpisode, :tv_show_id, %w[season episode])
      when Comic then move_children(ComicIssue, :comic_id, %w[issue_number])
      when VideoGame then transfer_game_identity!
      end
    end

    def transfer_game_identity!
      overlap = @source.library_items.where(user_id: @target.library_items.select(:user_id)).exists?
      raise Conflict, 'Both games have library records for the same member. Review personal history before merging.' if
        overlap

      @source.game_external_ids.update_all(video_game_id: @target.id)
      return if @target.cover_image.attached? || !@source.cover_image.attached?

      @target.cover_image.attach(@source.cover_image.blob)
    end

    def move_children(model, foreign_key, identifiers)
      matches = identifiers.map do |key|
        <<~SQL.squish
          (retained.#{key} = #{model.table_name}.#{key} OR
          (retained.#{key} IS NULL AND #{model.table_name}.#{key} IS NULL))
        SQL
      end.join(' AND ')
      conflict = model.where(foreign_key => @source.id)
                      .joins("INNER JOIN #{model.table_name} retained ON #{matches}")
                      .where("retained.#{foreign_key} = ?", @target.id).exists?
      raise Conflict, 'Episodes or issues overlap. Resolve conflicting child records before merging.' if conflict

      model.where(foreign_key => @source.id).update_all(foreign_key => @target.id)
    end
  end
end
