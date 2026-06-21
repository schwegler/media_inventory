# frozen_string_literal: true

module Admin
  class BooksController < Admin::ApplicationController
    def search_api
      @book = Book.find(params[:id])

      if params[:query].present?
        require 'net/http'
        require 'json'

        url = URI("https://itunes.apple.com/search?term=#{URI.encode_www_form_component(params[:query])}&media=ebook&limit=10&country=US")
        response = Net::HTTP.get(url)
        data = JSON.parse(response)

        @results = data['results'] || []
      else
        @results = []
      end
    end

    def update_from_api
      @book = Book.find(params[:id])

      require 'net/http'
      require 'json'

      url = URI("https://itunes.apple.com/lookup?id=#{params[:api_id]}")
      response = Net::HTTP.get(url)
      data = JSON.parse(response)

      item = data['results']&.first || {}

      if @book.update(
        api_id: params[:api_id],
        title: item['trackName'] || @book.title,
        author: item['artistName'] || @book.author,
        publisher: item['sellerName'] || @book.publisher,
        release_year: item['releaseDate']&.split('-')&.first || @book.release_year,
        thumbnail_url: item['artworkUrl100']&.sub('100x100bb', '400x400bb') || @book.thumbnail_url,
        external_url: item['trackViewUrl'] || @book.external_url
      )
        redirect_to admin_book_path(@book), notice: 'Book updated from iTunes.'
      else
        redirect_to search_api_admin_book_path(@book), alert: 'Failed to update book.'
      end
    end

    def merge
      @book = Book.find(params[:id])
      @books = Book.where.not(id: @book.id).order(:title)
    end

    def do_merge
      @source_book = Book.find(params[:id])
      @target_book = Book.find(params[:target_id])

      ActiveRecord::Base.transaction do
        @source_book.likes.update_all(likeable_id: @target_book.id)
        @source_book.comments.update_all(commentable_id: @target_book.id)
        LibraryItem.where(item: @source_book).update_all(item_id: @target_book.id)
        @source_book.destroy!
      end

      redirect_to admin_book_path(@target_book), notice: 'Books were successfully merged.'
    end
  end
end
