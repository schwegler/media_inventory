# frozen_string_literal: true

class WebfingerController < ApplicationController
  def show
    resource = params[:resource].to_s.strip
    user = nil

    if resource.start_with?('acct:')
      handle = resource.sub('acct:', '').split('@').first
      user = User.find_by('LOWER(name) = ? OR LOWER(bsky_handle) = ?', handle.downcase, handle.downcase)
    end

    if user
      domain = request.host_with_port
      render json: {
        subject: resource,
        links: [
          {
            rel: 'self',
            type: 'application/activity+json',
            href: activitypub_actor_url(user.id, host: domain)
          }
        ]
      }
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end
end
