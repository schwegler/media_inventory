# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'

class BlueskyClient
  def initialize(user)
    @user = user
  end

  def pds_url
    @pds_url ||= begin
      doc = if @user.bsky_did.start_with?('did:plc:')
              uri = URI("https://plc.directory/#{@user.bsky_did}")
              JSON.parse(Net::HTTP.get(uri))
            elsif @user.bsky_did.start_with?('did:web:')
              host = @user.bsky_did.sub('did:web:', '')
              uri = URI("https://#{host}/.well-known/did.json")
              JSON.parse(Net::HTTP.get(uri))
            end

      if doc
        service = doc['service']&.find { |s| s['id'] == '#atproto_pds' }
        service&.dig('serviceEndpoint') || 'https://bsky.social'
      else
        'https://bsky.social'
      end
    rescue StandardError => e
      Rails.logger.error "Failed to resolve PDS for #{@user.bsky_did}: #{e.message}"
      'https://bsky.social'
    end
  end

  def post(text, title: 'Media Tracker')
    return false unless @user && @user.bsky_access_token.present?

    client = AtProto::Client.new(
      private_key: OmniAuth::Atproto::KeyManager.current_private_key,
      access_token: @user.bsky_access_token
    )

    facets = []
    embed = nil

    # Extract URLs for facets and embed card
    urls = URI.extract(text, %w[http https])
    urls.each do |url|
      # Strip trailing punctuation if accidentally matched
      url = url.sub(/[.,;:!?]\z/, '')
      
      start_idx = text.index(url)
      next unless start_idx
      
      byte_start = text[0...start_idx].bytesize
      byte_end = byte_start + url.bytesize

      facets << {
        index: { byteStart: byte_start, byteEnd: byte_end },
        features: [{ '$type' => 'app.bsky.richtext.facet#link', 'uri' => url }]
      }

      if embed.nil?
        embed = {
          '$type' => 'app.bsky.embed.external',
          'external' => {
            'uri' => url,
            'title' => title,
            'description' => 'View this item on Trove'
          }
        }
      end
    end

    # Extract hashtags
    text.to_enum(:scan, /(?<=^|\s)#([\p{L}\w]+)/).each do
      match = Regexp.last_match
      start_idx = match.begin(0)
      
      byte_start = text[0...start_idx].bytesize
      byte_end = byte_start + match[0].bytesize

      facets << {
        index: { byteStart: byte_start, byteEnd: byte_end },
        features: [{ '$type' => 'app.bsky.richtext.facet#tag', 'tag' => match[1] }]
      }
    end

    body = {
      repo: @user.bsky_did,
      collection: 'app.bsky.feed.post',
      record: {
        '$type' => 'app.bsky.feed.post',
        text: text,
        createdAt: Time.now.utc.iso8601
      }
    }
    
    body[:record][:facets] = facets if facets.any?
    body[:record][:embed] = embed if embed

    client.request(:post, "#{pds_url}/xrpc/com.atproto.repo.createRecord", body: body)
    true
  rescue StandardError => e
    Rails.logger.error "Bluesky posting error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if e.respond_to?(:backtrace)
    raise e
  end

  def profile
    return nil unless @user && @user.bsky_access_token.present?

    client = AtProto::Client.new(
      private_key: OmniAuth::Atproto::KeyManager.current_private_key,
      access_token: @user.bsky_access_token
    )

    client.request(:get, "#{pds_url}/xrpc/app.bsky.actor.getProfile", params: { actor: @user.bsky_did })
  rescue StandardError => e
    Rails.logger.error "Bluesky getProfile error: #{e.message}"
    nil
  end

  def resolve_handle(handle)
    client = AtProto::Client.new(
      private_key: OmniAuth::Atproto::KeyManager.current_private_key,
      access_token: nil
    )
    response = client.request(:get, 'https://bsky.social/xrpc/com.atproto.identity.resolveHandle',
                              params: { handle: handle })
    response['did']
  rescue StandardError => e
    Rails.logger.error "Bluesky resolveHandle error: #{e.message}"
    nil
  end
end
