# frozen_string_literal: true

class CredentialField < Administrate::Field::Base
  def to_s
    data.present? ? 'Configured (hidden)' : 'Not configured'
  end
end
