# frozen_string_literal: true

module Admin
  class DashboardController < ApplicationController
    def index
      @overview = Overview.new
      @snapshot = @overview.snapshot
    end

    def attention
      @filter = Catalog::FILTERS.key?(params[:health]) ? params[:health] : 'attention'
      @groups = Catalog::TYPES.map do |model|
        scope = Catalog.filter(model, @filter)
        [model, scope.count, Catalog.eager_load(scope).order(updated_at: :desc).limit(5)]
      end
    end
  end
end
