# frozen_string_literal: true

require 'csv'
require 'zip'
require 'net/http'
require 'json'

# rubocop:disable Metrics/ClassLength
class LetterboxdImportJob < ApplicationJob
  queue_as :default

  def perform(user_id, zip_path)
    @user = User.find(user_id)
    @zip_path = zip_path

    Zip::File.open(@zip_path) do |zip_file|
      # Import in order of precedence: watchlist, watched, diary, ratings, reviews
      import_watchlist(zip_file)
      import_watched(zip_file)
      import_diary(zip_file)
      import_ratings(zip_file)
      import_reviews(zip_file)
      import_likes(zip_file)
    end
  ensure
    FileUtils.rm_f(@zip_path)
  end

  private

  def import_watchlist(zip_file)
    entry = zip_file.find_entry('watchlist.csv') || zip_file.find_entry('letterboxd-watchlist.csv')
    return unless entry

    csv_data = entry.get_input_stream.read
    CSV.parse(csv_data, headers: true) do |row|
      movie = find_or_create_movie(row)
      next unless movie

      item = find_or_initialize_library_item(movie)
      item.in_backlog = true
      item.is_collected = false
      item.save!
    end
  end

  def import_watched(zip_file)
    entry = zip_file.find_entry('watched.csv') || zip_file.find_entry('letterboxd-watched.csv')
    return unless entry

    csv_data = entry.get_input_stream.read
    CSV.parse(csv_data, headers: true) do |row|
      movie = find_or_create_movie(row)
      next unless movie

      item = find_or_initialize_library_item(movie)
      item.consumed = true
      item.in_backlog = false
      item.is_collected = true
      item.save!
    end
  end

  def import_diary(zip_file)
    entry = zip_file.find_entry('diary.csv') || zip_file.find_entry('letterboxd-diary.csv')
    return unless entry

    csv_data = entry.get_input_stream.read
    CSV.parse(csv_data, headers: true) do |row|
      movie = find_or_create_movie(row)
      next unless movie

      item = find_or_initialize_library_item(movie)
      item.consumed = true
      item.in_backlog = false
      item.is_collected = true

      watched_date = row['Watched Date'] || row['Date']
      if watched_date.present?
        item.consumed_at = begin
          Date.parse(watched_date)
        rescue StandardError
          nil
        end
      end

      rating = row['Rating']
      item.rating = rating if rating.present?

      item.save!
    end
  end

  def import_ratings(zip_file)
    entry = zip_file.find_entry('ratings.csv') || zip_file.find_entry('letterboxd-ratings.csv')
    return unless entry

    csv_data = entry.get_input_stream.read
    CSV.parse(csv_data, headers: true) do |row|
      movie = find_or_create_movie(row)
      next unless movie

      item = find_or_initialize_library_item(movie)
      rating = row['Rating']
      item.rating = rating if rating.present?
      item.save!
    end
  end

  def import_reviews(zip_file)
    entry = zip_file.find_entry('reviews.csv') || zip_file.find_entry('letterboxd-reviews.csv')
    return unless entry

    csv_data = entry.get_input_stream.read
    CSV.parse(csv_data, headers: true) do |row|
      movie = find_or_create_movie(row)
      next unless movie

      item = find_or_initialize_library_item(movie)
      item.consumed = true
      item.in_backlog = false
      item.is_collected = true

      watched_date = row['Watched Date'] || row['Date']
      if watched_date.present?
        item.consumed_at = begin
          Date.parse(watched_date)
        rescue StandardError
          nil
        end
      end

      rating = row['Rating']
      item.rating = rating if rating.present?

      review = row['Review']
      item.review = review if review.present?

      item.save!
    end
  end

  def import_likes(zip_file)
    entry = zip_file.find_entry('likes/films.csv') || zip_file.find_entry('likes.csv')
    return unless entry

    csv_data = entry.get_input_stream.read
    CSV.parse(csv_data, headers: true) do |row|
      movie = find_or_create_movie(row)
      next unless movie

      Like.find_or_create_by!(user: @user, likeable: movie)
    end
  end

  def find_or_create_movie(row)
    title = row['Name']
    year = row['Year']&.to_i
    return nil if title.blank?

    movie = Movie.find_by(title: title, release_year: year)
    return movie if movie

    movie = Movie.new(title: title, release_year: year, external_url: row['Letterboxd URI'])

    # Enrich from Wikipedia
    wiki_data = fetch_movie_from_wikipedia(title, year)
    if wiki_data
      movie.thumbnail_url = wiki_data[:thumbnail_url]
      movie.director = wiki_data[:director] || 'Various'
      movie.api_id = wiki_data[:api_id]
      movie.external_url = wiki_data[:external_url] if movie.external_url.blank?
    end

    movie.save!
    movie
  end

  def find_or_initialize_library_item(movie)
    LibraryItem.find_or_initialize_by(user: @user, item: movie)
  end

  def fetch_movie_from_wikipedia(title, year)
    search_query = year ? "#{title} #{year} film" : "#{title} film"
    search_url = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=#{CGI.escape(search_query)}&format=json&origin=*"
    uri = URI(search_url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
    search_results = data.dig('query', 'search') || []

    result = search_results.first
    return nil unless result

    page_title = result['title']
    summary_url = "https://en.wikipedia.org/api/rest_v1/page/summary/#{CGI.escape(page_title.gsub(' ', '_'))}"
    sum_response = Net::HTTP.get(URI(summary_url))
    sum_data = begin
      JSON.parse(sum_response)
    rescue StandardError
      {}
    end

    {
      thumbnail_url: sum_data.dig('originalimage', 'source'),
      api_id: "wiki_#{sum_data['pageid'] || page_title}",
      external_url: sum_data.dig('content_urls', 'desktop', 'page'),
      director: nil # Wikipedia API doesn't easily return structured director info in the summary
    }
  rescue StandardError => e
    Rails.logger.error "Wikipedia movie search failed for '#{title}': #{e.message}"
    nil
  end
end

# rubocop:enable Metrics/ClassLength
