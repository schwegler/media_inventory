# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin media and moderation workflows', type: :request do
  let(:admin) { User.create!(name: 'Reviewer', email: 'reviewer@example.com', password: 'password', admin: true) }
  let(:movie) { Movie.create!(title: 'Original', release_year: 2020) }
  let(:suggestion) { EditSuggestion.create!(user: admin, suggestable: movie, proposed_changes: { title: 'Proposed' }) }

  before { post login_path, params: { session: { email: admin.email, password: 'password' } } }

  it 'renders a readable comparison and confirmed review actions' do
    get admin_edit_suggestion_path(suggestion)
    expect(response.body).to include('Current value', 'Proposed value', 'Original', 'Proposed', '<mark>',
                                     'data-turbo-confirm')
  end

  it 'filters suggestions by status' do
    suggestion
    EditSuggestion.create!(user: admin, suggestable: movie, status: 'rejected', proposed_changes: { director: 'Someone' })
    get admin_edit_suggestions_path(status: 'pending')
    expect(response.body).to include('Title')
    expect(response.body).not_to include('Director')
  end

  it 'does not apply a decision twice or notify twice' do
    2.times { post approve_admin_edit_suggestion_path(suggestion) }
    expect(Notification.where(notifiable: suggestion, action: 'approved_edit').count).to eq(1)
    expect(suggestion.reload.status).to eq('approved')
  end

  it 'refuses unsupported proposed changes' do
    suggestion.update!(proposed_changes: { id: 123, title: 'Changed' })
    post approve_admin_edit_suggestion_path(suggestion)
    expect(suggestion.reload.status).to eq('pending')
    expect(movie.reload.title).to eq('Original')
    expect(flash[:alert]).to include('unsupported fields')
  end

  it 'rejects unsafe link schemes before applying untrusted suggestions' do
    suggestion.update!(proposed_changes: { external_url: 'javascript:alert(1)' })
    post approve_admin_edit_suggestion_path(suggestion)
    expect(suggestion.reload.status).to eq('pending')
    expect(movie.reload.external_url).to be_nil
    expect(flash[:alert]).to include('HTTP or HTTPS')
    suggestion.update!(proposed_changes: { external_url: 'https://example.com/movie' })
    post approve_admin_edit_suggestion_path(suggestion)
    expect(suggestion.reload.status).to eq('approved')
    expect(movie.reload.external_url).to eq('https://example.com/movie')
  end

  it 'rolls back the media and decision when notification persistence fails' do
    allow(Notification).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Notification.new))
    post approve_admin_edit_suggestion_path(suggestion)
    expect(movie.reload.title).to eq('Original')
    expect(suggestion.reload.status).to eq('pending')
  end

  it 'protects rejected suggestions from subsequent approval' do
    post reject_admin_edit_suggestion_path(suggestion)
    post approve_admin_edit_suggestion_path(suggestion)
    expect(movie.reload.title).to eq('Original')
    expect(suggestion.reload.status).to eq('rejected')
  end

  it 'fills blank metadata without replacing existing values or accepting arbitrary attributes' do
    post update_from_api_admin_movie_path(movie),
         params: { api_data: { title: 'Provider title', director: 'Director', id: 99 } }
    expect(movie.reload).to have_attributes(title: 'Original', director: 'Director')
    expect(movie.id).not_to eq(99)
    expect(flash[:notice]).to include('successfully updated')
  end

  it 'offers books the same metadata search and merge workflow' do
    book = Book.create!(title: 'Book')
    allow(MediaSearchService).to receive(:call).with('Book', 'book').and_return([{ title: 'Book', author: 'Writer' }])
    get search_api_admin_book_path(book)
    expect(response).to have_http_status(:ok)
    post update_from_api_admin_book_path(book), params: { api_data: { author: 'Writer' } }
    expect(book.reload.author).to eq('Writer')
    get merge_admin_book_path(book)
    expect(response).to have_http_status(:ok)
  end

  it 'protects a source from being merged into itself' do
    post do_merge_admin_movie_path(movie), params: { target_id: movie.id }
    expect(Movie.exists?(movie.id)).to be true
    expect(flash[:alert]).to include('different record')
  end

  it 'moves associations and suggestions and deduplicates likes before deleting the source' do
    target = Movie.create!(title: 'Retained')
    item = LibraryItem.create!(user: admin, item: movie, is_collected: true)
    comment = Comment.create!(user: admin, commentable: movie, content: 'History')
    source_activity = Activity.create!(user: admin, trackable: movie, activity_type: 'added')
    Like.create!(user: admin, likeable: movie)
    Like.create!(user: admin, likeable: target)
    suggestion
    post do_merge_admin_movie_path(movie), params: { target_id: target.id }
    expect(Movie.exists?(movie.id)).to be false
    expect(item.reload.item).to eq(target)
    expect(comment.reload.commentable).to eq(target)
    expect(source_activity.reload.trackable).to eq(target)
    expect(suggestion.reload.suggestable).to eq(target)
    expect(Like.where(likeable: target).count).to eq(1)
    expect(response).to redirect_to(admin_movie_path(target))
  end

  it 'preserves non-conflicting episodes and blocks conflicting episodes' do
    source = TvShow.create!(title: 'Source show')
    target = TvShow.create!(title: 'Retained show')
    episode = TvEpisode.create!(tv_show: source, name: 'Pilot', season: 1, episode: 1)
    TvEpisode.create!(tv_show: target, name: 'Other', season: 1, episode: 1)
    post do_merge_admin_tv_show_path(source), params: { target_id: target.id }
    expect(TvShow.exists?(source.id)).to be true
    expect(episode.reload.tv_show).to eq(source)
    expect(flash[:alert]).to include('overlap')
    target.tv_episodes.destroy_all
    post do_merge_admin_tv_show_path(source), params: { target_id: target.id }
    expect(episode.reload.tv_show).to eq(target)
    expect(TvShow.exists?(source.id)).to be false
  end

  it 'preserves comic issues on a merge' do
    source = Comic.create!(title: 'Source comic')
    target = Comic.create!(title: 'Retained comic')
    issue = ComicIssue.create!(comic: source, title: 'First', issue_number: 1)
    post do_merge_admin_comic_path(source), params: { target_id: target.id }
    expect(issue.reload.comic).to eq(target)
    expect(Comic.exists?(source.id)).to be false
  end
end
