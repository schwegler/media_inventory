# frozen_string_literal: true

class MediaController < ApplicationController
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def autocomplete
    q = params[:q].to_s.strip
    type = params[:type].to_s.strip

    if q.blank?
      render json: []
      return
    end

    results = []
    case type
    when 'movie'
      results = Movie.where('LOWER(title) LIKE ?', "%#{q.downcase}%").limit(5).map do |m|
        {
          title: m.title,
          director: m.director,
          release_year: m.release_year,
          thumbnail_url: m.cover_image.attached? ? url_for(m.cover_image) : m.thumbnail_url,
          is_local: true
        }
      end
    when 'album'
      results = Album.where('LOWER(title) LIKE ?', "%#{q.downcase}%").limit(5).map do |a|
        {
          title: a.title,
          artist: a.artist,
          genre: a.genre,
          release_year: a.release_year,
          thumbnail_url: a.cover_image.attached? ? url_for(a.cover_image) : a.thumbnail_url,
          is_local: true
        }
      end
    when 'comic'
      results = Comic.where('LOWER(title) LIKE ?', "%#{q.downcase}%").limit(5).map do |c|
        {
          title: c.title,
          writer: c.writer,
          artist: c.artist,
          publisher: c.publisher,
          issue_number: c.issue_number,
          thumbnail_url: c.cover_image.attached? ? url_for(c.cover_image) : c.thumbnail_url,
          api_id: c.api_id,
          is_local: true
        }
      end
    when 'tv_show'
      results = TvShow.where('LOWER(title) LIKE ?', "%#{q.downcase}%").limit(5).map do |t|
        {
          title: t.title,
          network: t.network,
          season: t.season,
          episode: t.episode,
          thumbnail_url: t.cover_image.attached? ? url_for(t.cover_image) : t.thumbnail_url,
          api_id: t.api_id,
          is_local: true
        }
      end
    when 'wrestling_event'
      results = WrestlingEvent.where('LOWER(title) LIKE ?', "%#{q.downcase}%").limit(5).map do |w|
        {
          title: w.title,
          promotion: w.promotion,
          venue: w.venue,
          date: w.date&.to_s,
          thumbnail_url: w.cover_image.attached? ? url_for(w.cover_image) : w.thumbnail_url,
          is_local: true
        }
      end
    end

    render json: results
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
end
