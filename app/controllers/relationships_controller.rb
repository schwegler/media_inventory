# frozen_string_literal: true

class RelationshipsController < ApplicationController
  before_action :logged_in_user

  def create
    user = User.find(params[:followed_id])
    current_user.follow(user)
    flash[:success] = "You are now following #{user.name}"
    redirect_back fallback_location: user
  end

  def destroy
    user = Relationship.find(params[:id]).followed
    current_user.unfollow(user)
    flash[:info] = "You have unfollowed #{user.name}"
    redirect_back fallback_location: user
  end
end
