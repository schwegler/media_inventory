# frozen_string_literal: true

# Administrate 1.0.0 still uses String#mb_chars in its search query builder,
# which Rails 8.1 deprecates. Use Ruby's native Unicode-aware downcase instead.
require 'administrate/search'

module AdministrateSearchStringDowncase
  private

  def query_values
    fields_count = search_attributes.sum do |attr|
      searchable_fields(attr).count
    end
    ["%#{term.downcase}%"] * fields_count
  end
end

Administrate::Search.prepend(AdministrateSearchStringDowncase)
