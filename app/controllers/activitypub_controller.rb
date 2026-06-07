# frozen_string_literal: true

class ActivitypubController < ApplicationController
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
    activities = @user.activities.where(activity_type: 'reviewed').order(created_at: :desc).limit(20)
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

  def outbox_item_for(act, domain)
    review_url = begin
      polymorphic_url(act.trackable, host: domain)
    rescue StandardError
      nil
    end
    return nil if review_url.nil?

    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "#{activitypub_outbox_url(@user.id, host: domain)}/activity/#{act.id}",
      type: 'Create',
      actor: activitypub_actor_url(@user.id, host: domain),
      object: {
        id: "#{review_url}#review-#{act.id}",
        type: 'Note',
        published: act.created_at.utc.iso8601,
        attributedTo: activitypub_actor_url(@user.id, host: domain),
        content: "Reviewed #{act.trackable&.title}: #{act.trackable&.review} (#{act.trackable&.rating} stars)",
        to: ['https://www.w3.org/ns/activitystreams#Public']
      }
    }
  end
end
