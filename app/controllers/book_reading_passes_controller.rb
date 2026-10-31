# frozen_string_literal: true

class BookReadingPassesController < ApplicationController
  before_action :logged_in_user

  def create
    edition = BookEdition.find(params[:book_edition_id])
    library = current_user.library_items.find_by!(item: edition.book)
    library.with_lock do
      scope = library.book_reading_passes.where(book_edition: edition)
      # An expected pass number makes double submission/retry idempotent.
      expected = params[:previous_number].to_s
      current = scope.maximum(:number) || 0
      scope.create!(book_edition: edition, number: current + 1) if expected == current.to_s
    end
    redirect_to book_path(edition.book, anchor: "edition-#{edition.id}"), notice: 'Reading/listening pass ready.'
  end

  def update
    pass = BookReadingPass.joins(:library_item).where(library_items: { user_id: current_user.id }).find(params[:id])
    chapter = pass.book_edition.book_chapters.find(params[:chapter_id])
    pass.with_lock do
      if ActiveModel::Type::Boolean.new.cast(params[:completed])
        pass.book_chapter_completions.find_or_create_by!(book_chapter: chapter)
      else
        pass.book_chapter_completions.where(book_chapter: chapter).destroy_all
      end
    end
    redirect_to book_path(pass.book_edition.book, anchor: "edition-#{pass.book_edition_id}")
  end
end
