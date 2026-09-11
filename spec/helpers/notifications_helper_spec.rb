# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotificationsHelper, type: :helper do
  describe '#notification_target_path' do
    let(:user) do
      User.create!(
        name: 'Test User',
        email: 'test@example.com',
        password: 'password',
        password_confirmation: 'password',
        confirmed_at: Time.current
      )
    end
    let(:actor) do
      User.create!(
        name: 'Actor User',
        email: 'actor@example.com',
        password: 'password',
        password_confirmation: 'password',
        confirmed_at: Time.current
      )
    end
    let(:movie) { Movie.create!(title: 'Inception') }

    it 'returns nil when notification is nil or has no notifiable' do
      expect(helper.notification_target_path(nil)).to be_nil
      notification = Notification.new
      expect(helper.notification_target_path(notification)).to be_nil
    end

    it 'returns path for a Like on a Movie' do
      like = Like.create!(user: actor, likeable: movie)
      notification = Notification.create!(recipient: user, actor: actor, action: 'liked', notifiable: like)
      expect(helper.notification_target_path(notification)).to eq(movie_path(movie))
    end

    it 'returns path for a Comment on a Movie' do
      comment = Comment.create!(user: actor, commentable: movie, content: 'Great movie!')
      notification = Notification.create!(recipient: user, actor: actor, action: 'commented', notifiable: comment)
      expect(helper.notification_target_path(notification)).to eq(movie_path(movie))
    end

    it 'returns path for an EditSuggestion' do
      suggestion = EditSuggestion.create!(user: actor, suggestable: movie, proposed_changes: { 'title' => 'Inception 2' })
      notification = Notification.create!(recipient: user, actor: actor, action: 'approved_edit', notifiable: suggestion)
      expect(helper.notification_target_path(notification)).to eq(movie_path(movie))
    end
  end
end
