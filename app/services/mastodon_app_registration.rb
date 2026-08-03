# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'

class MastodonAppRegistration
  def self.register(server, callback_url)
    # Ensure server is a plain hostname without http/https
    host = server.to_s.sub(%r{^https?://}, '').split('/').first
    return nil if host.blank?

    # Security: Validate host to prevent Server-Side Request Forgery (SSRF)
    return nil unless safe_host?(host)

    app = MastodonOauthApplication.find_by(server: host)
    return app if app

    # Register new app
    uri = URI("https://#{host}/api/v1/apps")
    req = build_request(uri, callback_url)

    execute_registration(host, uri, req)
  end

  # Security helper: Validate hostname to prevent Server-Side Request Forgery (SSRF)
  # by ensuring resolved IP addresses are public, non-private, non-loopback, and non-link-local.
  def self.safe_host?(host)
    require 'resolv'
    require 'ipaddr'

    clean_host = host.to_s.split(':').first
    return false if clean_host.blank?

    begin
      ips = Resolv.getaddresses(clean_host)
    rescue StandardError
      ips = []
    end
    return false if ips.empty?

    ips.all? do |ip_str|
      ip = IPAddr.new(ip_str)
      !ip.private? && !ip.loopback? && !(ip.respond_to?(:link_local?) && ip.link_local?)
    rescue StandardError
      false
    end
  end

  def self.build_request(uri, callback_url)
    req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    req.body = {
      client_name: 'Media Inventory',
      redirect_uris: callback_url,
      scopes: 'read write',
      website: 'https://github.com/lasercats/media_inventory' # Adjust as necessary
    }.to_json
    req
  end

  def self.execute_registration(host, uri, req)
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    if response.code == '200'
      data = JSON.parse(response.body)
      MastodonOauthApplication.create!(
        server: host,
        client_id: data['client_id'],
        client_secret: data['client_secret']
      )
    else
      Rails.logger.error "Mastodon app registration failed for #{host}: #{response.body}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "Mastodon app registration error for #{host}: #{e.message}"
    nil
  end
end
