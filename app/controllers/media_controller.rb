# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class MediaController < ApplicationController
  before_action :logged_in_user, only: :copy

  def copy
    source_type = params[:source_type].to_s.strip
    source_id = params[:source_id]
    target_list = params[:target_list].to_s.strip

    klass = source_type.classify.safe_constantize
    if klass.nil?
      redirect_back fallback_location: root_path, alert: 'Invalid media type.'
      return
    end

    item = klass.find(source_id)
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

    # Copy Active Storage cover image if attached
    new_item.cover_image.attach(item.cover_image.blob) if item.cover_image.attached?

    if new_item.save
      redirect_to new_item, notice: "#{klass.model_name.human} added to your #{target_list}."
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
              when 'wrestling_event' then autocomplete_wrestling_events(q)
              else []
              end

    render json: results
  end

  private

  def autocomplete_movies(query)
    Movie.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |m|
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
    Album.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |a|
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
    Comic.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |c|
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
    TvShow.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |t|
      {
        title: t.title,
        network: t.network,
        season: t.season,
        episode: t.episode,
        thumbnail_url: t.cover_image.attached? ? url_for(t.cover_image) : t.thumbnail_url,
        api_id: t.api_id,
        external_url: t.external_url,
        is_local: true
      }
    end
  end

  def autocomplete_wrestling_events(query)
    WrestlingEvent.where('LOWER(title) LIKE ?', "%#{query.downcase}%").limit(5).map do |w|
      {
        title: w.title,
        promotion: w.promotion,
        venue: w.venue,
        date: w.date&.to_s,
        thumbnail_url: w.cover_image.attached? ? url_for(w.cover_image) : w.thumbnail_url,
        api_id: w.api_id,
        external_url: w.external_url,
        is_local: true
      }
    end
  end
end
# rubocop:enable Metrics/ClassLength
