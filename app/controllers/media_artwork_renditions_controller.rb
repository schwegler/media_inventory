# frozen_string_literal: true

# Signed capability URLs protect private uploaded derivatives from ID enumeration.
class MediaArtworkRenditionsController < ApplicationController
  def show
    row = MediaArtworkRendition.find_signed!(params[:token], purpose: 'artwork-rendition')
    blob = row.blob if row.state == 'ready'
    if blob && MediaCoverImporter.stored_file?(blob)
      expires_in 5.minutes, public: true
      return redirect_to rails_storage_proxy_path(blob)
    end

    retry_missing(row)
    source = row.source_blob
    return redirect_to rails_storage_proxy_path(source) if MediaCoverImporter.stored_file?(source)

    response.headers['Cache-Control'] = 'no-store'
    send_file Rails.root.join('public/missing-game-cover.svg'), type: 'image/svg+xml', disposition: 'inline'
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  end

  private

  def retry_missing(row)
    eligible = MediaArtworkRendition.where(id: row.id, state: 'ready').or(
      MediaArtworkRendition.where(id: row.id, state: %w[failed pending processing]).where('updated_at < ?', 5.minutes.ago)
    )
    return if eligible.update_all(state: 'pending', updated_at: Time.current).zero?

    GenerateMediaArtworkRenditionJob.perform_later(row)
  end
end
