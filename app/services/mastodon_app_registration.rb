# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require 'resolv'
require 'ipaddr'

class MastodonAppRegistration
  def self.register(server, callback_url)
    # Ensure server is a plain hostname without http/https
    host = server.to_s.sub(%r{^https?://}, '').split('/').first
    return nil if host.blank? || !safe_host?(host)

    app = MastodonOauthApplication.find_by(server: host)
    return app if app

    # Register new app
    uri = URI("https://#{host}/api/v1/apps")
    req = build_request(uri, callback_url)

    execute_registration(host, uri, req)
  end

  # Validates that the host resolves to public IP addresses to mitigate SSRF vulnerabilities.
  def self.safe_host?(host)
    ips = Resolv.getaddresses(host)
    return false if ips.empty?

    ips.all? do |ip_str|
      ip = IPAddr.new(ip_str)
      !ip.private? && !ip.loopback? && !ip.link_local?
    end
  rescue StandardError
    false
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
