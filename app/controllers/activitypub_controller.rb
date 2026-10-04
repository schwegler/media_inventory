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

  # rubocop:disable Metrics/MethodLength
  def outbox_item_for(act, domain)
    return nil unless act.trackable.present?
    # Ensure private user items are omitted to prevent information disclosure
    return nil if act.trackable.respond_to?(:is_public) && !act.trackable.is_public

    # Extract target media item if trackable is a LibraryItem wrapper
    target = act.trackable.is_a?(LibraryItem) ? act.trackable.item : act.trackable
    return nil if target.nil?

    review_url = begin
      polymorphic_url(target, host: domain)
    rescue StandardError
      nil
    end
    return nil if review_url.nil?

    # HTML-escape user controlled fields to prevent stored XSS
    title = ERB::Util.html_escape(target.try(:title) || target.try(:name) || '')
    review = ERB::Util.html_escape(act.trackable.try(:review).to_s)
    rating = act.trackable.try(:rating)

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
        content: "Reviewed #{title}: #{review} (#{rating} stars)",
        to: ['https://www.w3.org/ns/activitystreams#Public']
      }
    }
  end
  # rubocop:enable Metrics/MethodLength
end
