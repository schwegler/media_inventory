# frozen_string_literal: true

class MediaArtworkSource < ApplicationRecord
  belongs_to :blob, class_name: 'ActiveStorage::Blob'
  serialize :provenance, coder: JSON
end
