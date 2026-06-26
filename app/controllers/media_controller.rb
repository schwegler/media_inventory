# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class MediaController < ApplicationController
  before_action :logged_in_user, only: :copy

  def copy
    source_type = params[:source_type].to_s.strip
    allowed_types = %w[Movie TvShow TvEpisode Album Comic VideoGame]
    unless allowed_types.include?(source_type)
      redirect_back fallback_location: root_path, alert: 'Invalid media type.'
      return
    end

    klass = source_type.constantize
    item = klass.find(params[:source_id])

    unless can_access?(item)
      redirect_to root_path, alert: 'Not authorized'
      return
    end

    new_item = build_copied_item(item, params[:target_list].to_s.strip)

    if new_item.save
      redirect_to new_item, notice: "#{klass.model_name.human} added to your #{params[:target_list]}."
    else
      redirect_back fallback_location: root_path, alert: 'Failed to add item.'
    end
  end

  def autocomplete
    q = params[:q].to_s.strip
    type = params[:type].to_s.strip

    if q.blank?
      render json: []
      return
    end

    results = case type
              when 'movie' then autocomplete_movies(q)
              when 'album' then autocomplete_albums(q)
              when 'comic' then autocomplete_comics(q)
              when 'tv_show' then autocomplete_tv_shows(q)
              when 'video_game' then autocomplete_video_games(q)
              when 'book' then autocomplete_books(q)
              else []
              end

    render json: results
  end

  private

  def build_copied_item(item, target_list)
    new_item = item.dup
    new_item.user = current_user

    if target_list == 'collection'
      new_item.is_collected = true
      new_item.in_watchlist = false
    else
      new_item.is_collected = false
      new_item.in_watchlist = true
      new_item.consumed = false
    end

    new_item.cover_image.attach(item.cover_image.blob) if item.cover_image.attached?
    new_item
  end

  def autocomplete_movies(query)
    local_results = fetch_local_movies(query)
    web_results = MediaSearchService.call(query, 'movie')

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_movies(query)
    Movie.visible_to(current_user).where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |m|
      {
        title: m.title,
        director: m.director,
        release_year: m.release_year,
        thumbnail_url: m.cover_image.attached? ? url_for(m.cover_image) : m.thumbnail_url,
        api_id: m.api_id,
        external_url: m.external_url,
        is_local: true
      }
    end
  end

  def autocomplete_albums(query)
    local_results = fetch_local_albums(query)
    web_results = MediaSearchService.call(query, 'album')

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_albums(query)
    Album.visible_to(current_user).where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |a|
      {
        title: a.title,
        artist: a.artist,
        genre: a.genre,
        release_year: a.release_year,
        thumbnail_url: a.cover_image.attached? ? url_for(a.cover_image) : a.thumbnail_url,
        api_id: a.api_id,
        external_url: a.external_url,
        is_local: true
      }
    end
  end

  def autocomplete_comics(query)
    local_results = fetch_local_comics(query)
    web_results = MediaSearchService.call(query, 'comic')

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_comics(query)
    Comic.visible_to(current_user).where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |c|
      {
        title: c.title,
        writer: c.writer,
        artist: c.artist,
        publisher: c.publisher,
        issue_number: c.issue_number,
        thumbnail_url: c.cover_image.attached? ? url_for(c.cover_image) : c.thumbnail_url,
        api_id: c.api_id,
        external_url: c.external_url,
        is_local: true
      }
    end
  end

  def autocomplete_tv_shows(query)
    local_results = fetch_local_tv_shows(query)
    web_results = MediaSearchService.call(query, 'tv_show')

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_tv_shows(query)
    TvShow.visible_to(current_user).where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |t|
      {
        title: t.title,
        network: t.network,
        thumbnail_url: t.cover_image.attached? ? url_for(t.cover_image) : t.thumbnail_url,
        api_id: t.api_id,
        external_url: t.external_url,
        is_local: true
      }
    end
  end

  def autocomplete_video_games(query)
    local_results = fetch_local_video_games(query)
    web_results = MediaSearchService.call(query, 'video_game')

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_video_games(query)
    VideoGame.visible_to(current_user).where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(3).map do |vg|
      {
        title: vg.title,
        developer: vg.developer,
        publisher: vg.publisher,
        platform: vg.platform,
        release_year: vg.release_year,
        thumbnail_url: vg.cover_image.attached? ? url_for(vg.cover_image) : vg.thumbnail_url,
        api_id: vg.api_id,
        external_url: vg.external_url,
        is_local: true
      }
    end
  end

  def autocomplete_books(query)
    local_results = fetch_local_books(query)
    web_results = MediaSearchService.call(query, 'book')

    filter_unique_results(local_results + web_results)
  end

  def fetch_local_books(query)
    Book.visible_to(current_user).where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |b|
      {
        title: b.title,
        author: b.author,
        publisher: b.publisher,
        release_year: b.release_year,
        thumbnail_url: b.cover_image.attached? ? url_for(b.cover_image) : b.thumbnail_url,
        api_id: b.api_id,
        external_url: b.external_url,
        is_local: true
      }
    end
  end

  def filter_unique_results(all_results)
    seen = {}
    all_results.select do |item|
      key = "#{item[:title].to_s.downcase.strip}_#{item[:release_year]}"

      if seen[key]
        false
      else
        seen[key] = true
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
