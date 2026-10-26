# frozen_string_literal: true

class ActivitypubController < ApplicationController
  include ItemSharingHelper
  include ReviewPagesHelper

  skip_before_action :verify_authenticity_token, only: [:inbox]

  def actor
    @user = User.find(params[:id])
    domain = request.host_with_port

    render json: {
      '@context': [
        'https://www.w3.org/ns/activitystreams',
        'https://w3id.org/security/v1'
      ],
      id: activitypub_actor_url(@user.id, host: domain),
      type: 'Person',
      preferredUsername: @user.name.to_s.parameterize,
      name: @user.name,
      inbox: activitypub_inbox_url(@user.id, host: domain),
      outbox: activitypub_outbox_url(@user.id, host: domain),
      publicKey: {
        id: "#{activitypub_actor_url(@user.id, host: domain)}#main-key",
        owner: activitypub_actor_url(@user.id, host: domain),
        publicKeyPem: @user.public_key
      }
    }, content_type: 'application/activity+json'
  end

  def outbox
    @user = User.find(params[:id])
    domain = request.host_with_port
    response.headers['Cache-Control'] = 'private, no-store'
    activities = public_outbox_activities
    items = activities.map { |act| outbox_item_for(act, domain) }.compact

    render json: {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: activitypub_outbox_url(@user.id, host: domain),
      type: 'OrderedCollection',
      totalItems: items.size,
      orderedItems: items
    }, content_type: 'application/activity+json'
  end

  def inbox
    render json: { status: 'accepted' }, status: :ok
  end

  private

  def public_outbox_activities
    scope = DashboardActivityQuery.new(@user.activities).visible(reviews_only: true)
    activities = scope.order(created_at: :desc).limit(20).to_a
    ActiveRecord::Associations::Preloader.new(records: activities, associations: :trackable).call
    DashboardActivityQuery.attach_review_entries(activities)
    entries = activities.map(&:trackable).grep(LibraryItem)
    ActiveRecord::Associations::Preloader.new(records: entries, associations: :item).call
    items = entries.map(&:item).compact
    ActiveRecord::Associations::Preloader.new(records: items.grep(TvEpisode), associations: :tv_show).call
    ActiveRecord::Associations::Preloader.new(records: items.grep(ComicIssue), associations: :comic).call
    activities
  end

  def outbox_item_for(act, domain)
    entry = act.trackable
    return unless entry.is_a?(LibraryItem) && entry.is_public? && entry.review.present? && entry.item
    return unless entry.user_id == @user.id && ReviewsController::REVIEWABLE_MODELS.key?(entry.item_type)
    return if entry.item.is_a?(TvEpisode) && !entry.item.tv_show
    return if entry.item.is_a?(ComicIssue) && !entry.item.comic

    review_url = canonical_review_url(entry)
    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "#{activitypub_outbox_url(@user.id, host: domain)}/activity/#{act.id}",
      type: 'Create',
      actor: activitypub_actor_url(@user.id, host: domain),
      object: {
        id: review_url,
        url: review_url,
        type: 'Note',
        published: act.created_at.utc.iso8601,
        attributedTo: activitypub_actor_url(@user.id, host: domain),
        content: outbox_review_content(entry, review_url),
        to: ['https://www.w3.org/ns/activitystreams#Public']
      }
    }
  end

  def outbox_review_content(entry, review_url)
    rating = " (#{entry.rating} out of 5 stars)" if entry.rating.present?
    helpers.safe_join([
                        helpers.content_tag(:p, "Reviewed #{entry.item.title}#{rating}"),
                        ReviewExcerpt.new(entry.review, length: 220, paragraphs: 2, breaks: 3).html,
                        helpers.link_to('View review', review_url)
                      ])
  end
end
