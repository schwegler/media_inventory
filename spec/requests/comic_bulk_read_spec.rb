# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bulk issue tracking', type: :request do
  let!(:comic) { Comic.create!(title: 'Bulk comic') }
  let!(:issue) { comic.comic_issues.create!(title: 'First issue', issue_number: 1) }
  let!(:user) do
    User.create!(name: 'Reader', email: 'bulk@example.com', password: 'password123',
                 password_confirmation: 'password123', confirmed_at: Time.current)
  end

  it 'requires authentication' do
    patch mark_all_read_comic_path(comic)
    expect(response).to redirect_to(login_path)
    expect(LibraryItem.where(item: issue)).to be_empty
  end

  it 'preserves review and lifetime consumption when undoing a reread' do
    post login_path, params: { session: { email: user.email, password: 'password123' } }
    patch mark_all_read_comic_path(comic), params: { consumed: true }
    expect(response).to have_http_status(:see_other)
    child = LibraryItem.find_by!(user: user, item: issue)
    child.update!(rating: '4.5', review: 'Keep this review')
    series = LibraryItem.find_by!(user: user, item: comic)
    ConsumptionPasses.start(series)
    patch mark_all_read_comic_path(comic), params: { consumed: true }
    patch mark_all_read_comic_path(comic), params: { consumed: false }
    expect(child.reload.consumed?).to be true
    expect(child.review).to eq('Keep this review')
    expect(child.rating).to eq('4.5')
    expect(ConsumptionPasses.current_pass(series).entries).to be_empty
  end
end
