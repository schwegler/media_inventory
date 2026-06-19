# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UsersController, type: :controller do
  let(:user) { instance_double(User, id: 1, name: 'Test User', email: 'test@example.com', admin?: false) }
  let(:admin_user) { instance_double(User, id: 2, name: 'Admin User', email: 'admin@example.com', admin?: true) }

  describe 'GET #index' do
    context 'when not logged in' do
      it 'redirects to login' do
        get :index
        expect(response).to redirect_to(login_url)
        expect(flash[:danger]).to eq('Please log in.')
      end
    end

    context 'when logged in' do
      before do
        allow(controller).to receive(:logged_in?).and_return(true)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'assigns @users and returns success' do
        users = [user]
        allow(User).to receive(:page).and_return(users)

        get :index
        expect(controller.instance_variable_get(:@users)).to eq(users)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #show' do
    context 'when not logged in' do
      it 'redirects to login' do
        get :show, params: { id: user.id }
        expect(response).to redirect_to(login_url)
      end
    end

    context 'when logged in' do
      before do
        allow(controller).to receive(:logged_in?).and_return(true)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'assigns @user and returns success' do
        allow(User).to receive(:find).with(user.id.to_s).and_return(user)

        # Mocking associations for the show action
        activities = double('activities')
        allow(user).to receive(:activities).and_return(activities)
        allow(activities).to receive(:includes).and_return(activities)
        allow(activities).to receive(:order).and_return(activities)
        allow(activities).to receive(:limit).and_return(activities)
        allow(activities).to receive(:load).and_return(activities)

        likes = double('likes')
        allow(user).to receive(:likes).and_return(likes)
        allow(likes).to receive(:includes).and_return(likes)
        allow(likes).to receive(:order).and_return(likes)
        allow(likes).to receive(:load).and_return(likes)

        %i[movies albums comics tv_shows video_games].each do |media|
          relation = double(media.to_s)
          allow(user).to receive(media).and_return(relation)
          allow(relation).to receive(:where).with(is_public: true).and_return([])
        end

        get :show, params: { id: user.id }
        expect(controller.instance_variable_get(:@user)).to eq(user)
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when not logged in' do
      it 'redirects to login' do
        delete :destroy, params: { id: user.id }
        expect(response).to redirect_to(login_url)
      end
    end

    context 'when logged in as non-admin' do
      before do
        allow(controller).to receive(:logged_in?).and_return(true)
        allow(controller).to receive(:current_user).and_return(user)
      end

      it 'redirects to root url' do
        delete :destroy, params: { id: user.id }
        expect(response).to redirect_to(root_url)
      end
    end

    context 'when logged in as admin' do
      before do
        allow(controller).to receive(:logged_in?).and_return(true)
        allow(controller).to receive(:current_user).and_return(admin_user)
      end

      it 'deletes the user and redirects to users index' do
        allow(User).to receive(:find).with(user.id.to_s).and_return(user)
        allow(user).to receive(:destroy).and_return(true)

        delete :destroy, params: { id: user.id }

        expect(user).to have_received(:destroy)
        expect(flash[:success]).to eq('User deleted')
        expect(response).to redirect_to(users_url)
      end
    end
  end
end
