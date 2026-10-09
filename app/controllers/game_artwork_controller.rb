# frozen_string_literal: true

class GameArtworkController < ApplicationController
  before_action :logged_in_user
  before_action :load_library

  def alternates
    return head :too_many_requests if MediaSources::Registry::CACHE.read(['game-alternate-cooldown', @library.id])

    MediaSources::Registry::CACHE.write(['game-alternate-cooldown', @library.id], true, expires_in: 1.minute)
    choices = GameAlternateArtwork.call(@library)
    MediaSources::Registry::CACHE.write(['game-alternate-choices', @library.id], choices, expires_in: 10.minutes)
    message = if choices.empty?
                'No eligible alternate covers were found. You can upload your own.'
              else
                'Choose an alternate cover below.'
              end
    redirect_to video_game_path(@library.item, anchor: 'my-game-tracking'),
                notice: message, status: :see_other
  end

  def select_cover
    data = Rails.application.message_verifier('game-cover-choice').verified(params[:token])
    data = data.with_indifferent_access if data.is_a?(Hash)
    return head :forbidden unless data.is_a?(Hash) && data[:library_id] == @library.id

    blob = ActiveStorage::Blob.find(data[:blob_id])
    return head :unprocessable_content unless MediaCoverImporter.stored_file?(blob)

    @library.game_cover_image.attach(blob)
    redirect_to video_game_path(@library.item), notice: 'Your personal cover was updated.', status: :see_other
  end

  def cover
    upload = params.require(:cover).fetch(:image)
    return head :payload_too_large if upload.size > MediaCoverImporter::MAX_BYTES

    mime = Marcel::MimeType.for(upload.tempfile)
    return head :unprocessable_content unless MediaCoverImporter::IMAGE_TYPES.include?(mime)

    MediaCoverImporter.validate_pixels!(upload.tempfile.path)
    upload.tempfile.rewind
    @library.game_cover_image.attach(io: upload.tempfile, filename: upload.original_filename, content_type: mime)
    redirect_to video_game_path(@library.item), notice: 'Your personal cover was saved.', status: :see_other
  rescue MediaSources::Http::Error, KeyError
    redirect_to video_game_path(@library.item), alert: 'Choose a valid image up to 5 MB.', status: :see_other
  end

  def repair
    return head :too_many_requests if MediaSources::Registry::CACHE.read(['game-repair', @library.id])

    MediaSources::Registry::CACHE.write(['game-repair', @library.id], true, expires_in: 5.minutes)
    item = @library.item
    check_remote_cover(item)
    ImportMediaCoverJob.perform_later(item, item.thumbnail_url) if item.thumbnail_url.present?
    redirect_to video_game_path(item), notice: 'Artwork repair queued. Custom covers are preserved.', status: :see_other
  end

  private

  def check_remote_cover(item)
    return unless item.cover_image.attached? && item.cover_image.blob.metadata['remote_source'].present?

    item.cover_image.blob.open { |file| MediaCoverImporter.validate_pixels!(file.path) }
  rescue ActiveStorage::IntegrityError, ActiveStorage::FileNotFoundError, MediaSources::Http::Error
    health = CoverImport.find_or_create_by!(item: item) { |entry| entry.source_url = item.thumbnail_url }
    health.update!(state: 'failed', failure_reason: 'Corrupted stored image')
  end

  def load_library
    @library = current_user.library_items.where(item_type: 'VideoGame').find_by!(item_id: params[:video_game_id])
  end
end
