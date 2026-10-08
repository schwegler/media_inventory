# frozen_string_literal: true

# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    include SessionsHelper

    helper SessionsHelper
    helper Admin::CommandCenterHelper
    layout 'admin/application'

    before_action :authenticate_admin

    def authenticate_admin
      redirect_to '/', alert: 'Not authorized.' unless logged_in? && current_user&.admin?
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end

    def scoped_resource
      scope = super
      if Catalog::TYPES.include?(resource_class)
        scope = scope.merge(Catalog.filter(resource_class, params[:health]))
        scope = scope.where(tv_show_id: params[:tv_show_id]) if resource_class == TvEpisode && params[:tv_show_id].present?
        scope = scope.where(comic_id: params[:comic_id]) if resource_class == ComicIssue && params[:comic_id].present?
        Catalog.eager_load(scope)
      elsif resource_class == EditSuggestion
        scope = scope.where(status: params[:status]) if %w[pending approved rejected].include?(params[:status])
        scope.includes(:user, :suggestable)
      else
        scope
      end
    end

    def resource_params
      permitted = super.reject { |key, value| credential_fields.include?(key.to_s) && value.blank? }
      clear = params.require(resource_class.model_name.param_key).permit(clear_credentials: [])[:clear_credentials] || []
      editable = dashboard.permitted_attributes(action_name).grep(Symbol).map(&:to_s)
      clear.each { |key| permitted[key] = nil if credential_fields.include?(key.to_s) && editable.include?(key.to_s) }
      permitted
    end

    def paginate_resources(resources)
      paginated = super
      records = paginated.to_a
      related = records.flat_map do |record|
        %i[item trackable commentable likeable suggestable].filter_map do |association|
          record.public_send(association) if record.class.reflect_on_association(association)
        end
      end
      RecordLabels.preload(records + related)
      paginated
    end

    def records_per_page
      20
    end

    def credential_fields
      %w[options access_token client_secret bsky_access_token bsky_refresh_token mastodon_access_token
         mastodon_refresh_token password_digest private_key]
    end

    protected

    def default_sorting_attribute
      :created_at
    end

    def default_sorting_direction
      :desc
    end
  end
end
