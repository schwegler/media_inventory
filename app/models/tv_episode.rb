# frozen_string_literal: true

class TvEpisode < ApplicationRecord
  belongs_to :tv_show
end
