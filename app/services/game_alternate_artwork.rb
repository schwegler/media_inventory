# frozen_string_literal: true

class GameAlternateArtwork
  ADAPTERS = { 'steam' => GameProviders::Steam, 'rawg' => GameProviders::Rawg }.freeze

  def self.call(library)
    new(library).call
  end

  def initialize(library)
    @library = library
    @game = library.item
    @deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
  end

  def call
    result = { title: @game.title, api_id: @game.api_id, source: 'catalog', game_type: @game.game_type,
               release_year: @game.release_year, developer: @game.developer }
    candidates = GameArtworkResolver.candidates(result, deadline: @deadline, alternate: true)
    candidates.concat(external_candidates)
    current = @game.cover_image.blob.metadata['remote_source'] if @game.cover_image.attached?
    candidates.uniq { |candidate| candidate[:url] }.first(3).filter_map do |candidate|
      next if candidate[:url].blank? || candidate[:url] == current

      choice(candidate)
    end
  end

  private

  def external_candidates
    @game.game_external_ids.filter_map do |identity|
      adapter = ADAPTERS[identity.provider]
      next unless adapter

      data = adapter.new(deadline: @deadline).artwork(identity.external_id)
      { url: data[:thumbnail_url], provider: identity.provider, matched_by: 'canonical_external_id',
        storage_eligible: true }
    rescue GameProviders::Base::Unavailable
      nil
    end
  end

  def choice(candidate)
    blob = GameSearchArtwork.acquire(candidate, @deadline)
    return unless blob

    token = Rails.application.message_verifier('game-cover-choice').generate(
      { library_id: @library.id, blob_id: blob.id }, expires_in: 10.minutes
    )
    { url: Rails.application.routes.url_helpers.rails_storage_proxy_path(blob, only_path: true),
      source: candidate[:provider], token: token }
  end
end
