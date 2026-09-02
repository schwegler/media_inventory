# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'shared/_comment.html.erb', type: :view do
  let(:user) { User.create!(name: 'Jane Doe', email: "jane_#{SecureRandom.hex(4)}@test.com", password: 'password') }
  let(:album) { Album.create!(title: 'Cool Album') }
  let(:comment) { Comment.create!(user: user, commentable: album, content: 'This is an awesome album!') }

  before do
    allow(view).to receive(:logged_in?).and_return(true)
    allow(view).to receive(:current_user).and_return(user)
  end

  it 'renders the reply button with correct ARIA and toggle attributes' do
    render partial: 'shared/comment', locals: { comment: comment, matching_item: album, depth: 0 }

    expect(rendered).to have_css('button.btn-reply[data-toggle-target="trigger"]')
    expect(rendered).to have_css("button.btn-reply[aria-label='Reply to Jane Doe']")
    expect(rendered).to have_css("button.btn-reply[aria-controls='reply-form-#{comment.id}']")
    expect(rendered).to have_css("button.btn-reply[aria-expanded='false']")
    expect(rendered).to have_css("#reply-form-#{comment.id}")
    expect(rendered).to have_css("input[data-toggle-target='input']")
  end

  it 'uses preloaded replies in memory without making extra SQL queries' do
    Comment.create!(user: user, commentable: album, parent_id: comment.id, content: 'Great review!')
    preloaded_comment = Comment.where(id: comment.id).includes(user: { avatar_attachment: :blob }, likes: :user,
                                                               replies: [:user, { replies: :user }]).first

    queries = []
    callback = lambda { |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == 'SCHEMA'
    }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      render partial: 'shared/comment', locals: { comment: preloaded_comment, matching_item: album, depth: 0 }
    end

    expect(rendered).to include('Great review!')
    expect(queries.grep(/"comments"/)).to be_empty
  end

  it 'renders comments box using preloaded comments without extra SQL queries' do
    Comment.create!(user: user, commentable: album, content: 'First comment')
    preloaded_album = Album.where(id: album.id).includes(comments: [:user, :likes, {
                                                           replies: [:user, :likes, { replies: :user }]
                                                         }]).first

    queries = []
    callback = lambda { |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == 'SCHEMA'
    }

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      render partial: 'shared/comments_box', locals: { matching_item: preloaded_album }
    end

    expect(rendered).to include('First comment')
    expect(queries.grep(/"comments"/)).to be_empty
  end
end
