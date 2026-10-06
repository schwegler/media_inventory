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
    trackable = act.trackable
    return nil if trackable.nil? || (trackable.respond_to?(:is_public) && !trackable.is_public)

    target = trackable.is_a?(LibraryItem) ? trackable.item : trackable
    return nil if target.nil?

    review_url = begin
      polymorphic_url(target, host: domain)
    rescue StandardError
      nil
    end
    return nil if review_url.nil?

    build_note_activity(act, trackable, review_url, domain)
  end

  def build_note_activity(act, trackable, review_url, domain)
    actor_url = activitypub_actor_url(@user.id, host: domain)
    title = ERB::Util.html_escape(trackable.title)
    review = ERB::Util.html_escape(trackable.review)

    {
      '@context': 'https://www.w3.org/ns/activitystreams',
      id: "#{activitypub_outbox_url(@user.id, host: domain)}/activity/#{act.id}",
      type: 'Create',
      actor: actor_url,
      object: {
        id: "#{review_url}#review-#{act.id}",
        type: 'Note',
        published: act.created_at.utc.iso8601,
        attributedTo: actor_url,
        content: "Reviewed #{title}: #{review} (#{trackable.rating} stars)",
        to: ['https://www.w3.org/ns/activitystreams#Public']
      }
    }
  end
end
