# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_comments_box.html.erb', type: :view do
  let(:user) { User.create!(name: 'Jane Doe', email: "jane_#{SecureRandom.hex(4)}@test.com", password: 'password') }
  let(:album) { Album.create!(title: 'Cool Album') }
  let!(:comment) { Comment.create!(user: user, commentable: album, content: 'This is an awesome album!') }
  let!(:reply) { Comment.create!(user: user, commentable: album, parent_id: comment.id, content: 'Replying to myself!') }

  before do
    allow(view).to receive(:logged_in?).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'renders comments box when comments are not pre-loaded' do
    render partial: 'shared/comments_box', locals: { matching_item: album }

    expect(rendered).to have_content('This is an awesome album!')
    expect(rendered).to have_content('Replying to myself!')
  end

  it 'renders comments box when comments are pre-loaded in memory' do
    preloaded_album = Album.includes(comments: %i[user replies]).find(album.id)
    render partial: 'shared/comments_box', locals: { matching_item: preloaded_album }

    expect(rendered).to have_content('This is an awesome album!')
    expect(rendered).to have_content('Replying to myself!')
  end
end
