# frozen_string_literal: true

class DiscoveryController < ApplicationController
  before_action :logged_in_user, only: :resume

  def create
    session[:discovery_intent] = DiscoveryIntent.store(type: params[:type].to_s,
                                                       selection: params[:selection], query: params[:q])
    redirect_to logged_in? ? resume_discovery_path : login_path, status: :see_other
  rescue MetadataImport::Invalid => e
    redirect_to search_path(q: params[:q].to_s.first(200)), alert: e.message, status: :see_other
  end

  def resume
    intent = DiscoveryIntent.read(session[:discovery_intent])
    if intent
      redirect_to new_polymorphic_path(intent[:type].camelize.constantize, discovery: '1')
    else
      session.delete(:discovery_intent)
      redirect_to search_path, alert: 'Your selection expired. Search and select the title again.'
    end
  end
end
