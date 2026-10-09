# frozen_string_literal: true

module CanonicalUrls
  extend ActiveSupport::Concern

  private

  # IDs keep old and renamed URLs resolvable; show pages consolidate on one URL.
  def redirect_to_canonical_url(record, param: :id, path: polymorphic_path(record))
    return if params[param].to_s == record.to_param

    location = request.query_string.present? ? "#{path}?#{request.query_string}" : path
    redirect_to location, status: :moved_permanently
  end
end
