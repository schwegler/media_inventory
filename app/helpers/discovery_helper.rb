# frozen_string_literal: true

module DiscoveryHelper
  def discovery_intent
    DiscoveryIntent.read(session[:discovery_intent])
  end

  def discovery_destination(fallback)
    discovery_intent ? resume_discovery_path : fallback
  end

  def discovery_search_path(intent = discovery_intent)
    type = intent && SearchController::MAPPINGS.find do |_key, (_result, klass)|
      klass.name.underscore == intent[:type]
    end&.first
    search_path(q: intent&.dig(:query), type: type)
  end
end
