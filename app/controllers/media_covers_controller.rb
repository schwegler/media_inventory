# frozen_string_literal: true

# Public catalog artwork uses stored record URLs, never a URL supplied to this endpoint.
class MediaCoversController < ApplicationController
  TYPES = { 'movie' => Movie, 'tv_show' => TvShow, 'album' => Album, 'video_game' => VideoGame,
            'comic' => Comic, 'book' => Book, 'tv_episode' => TvEpisode, 'comic_issue' => ComicIssue }.freeze

  def show
    type = TYPES[params[:type]]
    raise ActiveRecord::RecordNotFound unless type

    item = type.find(params[:id])
    recover_cover(item) unless available?(item)
    if available?(item)
      expires_in 5.minutes, public: true
      redirect_to rails_storage_proxy_path(item.cover_image, only_path: true)
    else
      response.headers['Cache-Control'] = 'no-store'
      send_file Rails.root.join(item.is_a?(VideoGame) ? 'public/missing-game-cover.svg' : 'public/favicon.svg'),
                type: 'image/svg+xml', disposition: 'inline'
    end
  end

  private

  def available?(item)
    item.cover_image.attached? && item.cover_image.blob.service.exist?(item.cover_image.blob.key)
  end

  def recover_cover(item)
    return if item.thumbnail_url.blank?

    key = ['cover-recovery-failed', item.class.name, item.id, item.thumbnail_url]
    return if MediaSources::Registry::CACHE.read(key)

    MediaCoverImporter.call(item, item.thumbnail_url)
    item.reload
    MediaSources::Registry::CACHE.write(key, true, expires_in: 1.minute) unless available?(item)
  end
end
