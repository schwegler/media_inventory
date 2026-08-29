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
end
