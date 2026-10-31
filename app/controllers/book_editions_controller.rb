# frozen_string_literal: true

class BookEditionsController < ApplicationController
  before_action :logged_in_user

  def update
    edition = BookEdition.find(params[:id])
    @book = edition.book
    return head :forbidden unless current_user.library_items.exists?(item: @book)

    edition.with_lock do
      raise BookChapterLists::Conflict, 'This edition already has a list; add a separate edition to preserve it.' if
        edition.book_chapters.exists?

      BookChapterLists.reconcile(edition, BookChapterLists.manual(params[:chapters]))
      edition.update!(complete_chapter_list: ActiveModel::Type::Boolean.new.cast(params[:complete_chapter_list]))
    end
    redirect_to book_path(@book, anchor: "edition-#{edition.id}"), notice: 'Chapter list added.'
  rescue ActiveRecord::RecordInvalid, BookChapterLists::Conflict => e
    redirect_to @book, alert: e.message
  end

  def create
    @book = Book.find(params[:book_id])
    return head :forbidden unless current_user.library_items.exists?(item: @book)

    attributes = params.require(:book_edition).permit(:label, :format, :structure_kind,
                                                      :complete_chapter_list, :isbn, :published_on).to_h
    # Stable content identity makes repeated submissions safe, without replacing any list.
    identity = "manual:#{Digest::SHA256.hexdigest([attributes.sort, params[:chapters].to_s.strip].to_json)}"
    edition = nil
    @book.with_lock do
      edition = @book.book_editions.find_or_initialize_by(identity_key: identity)
      if edition.new_record?
        edition.assign_attributes(attributes)
        edition.save!
        BookChapterLists.reconcile(edition, BookChapterLists.manual(params[:chapters])) if params[:chapters].present?
      end
    end
    redirect_to book_path(@book, anchor: "edition-#{edition.id}"), notice: 'Edition added.'
  rescue ActiveRecord::RecordInvalid, BookChapterLists::Conflict => e
    redirect_to @book, alert: e.message
  end
end
