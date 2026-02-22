# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WrestlingEvents', type: :request do # rubocop:disable Metrics/BlockLength
  let!(:user) do
    User.create!(name: 'Test User',
                 email: 'test@example.com',
                 password: 'password',
                 password_confirmation: 'password')
  end

  describe 'GET /wrestling_events' do
    it 'renders the index template' do
      get wrestling_events_path
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /wrestling_events/new' do
    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'renders the new template' do
        get new_wrestling_event_path
        expect(response).to have_http_status(200)
      end
    end

    context 'when not logged in' do
      it 'redirects to login path' do
        get new_wrestling_event_path
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe 'GET /wrestling_events/:id' do
    context 'when the event exists' do
      let(:wrestling_event) do
        WrestlingEvent.create!(title: 'WrestleMania 40',
                               promotion: 'WWE',
                               date: Date.new(2024, 4, 6),
                               venue: 'Lincoln Financial Field')
      end

      it 'renders the show template and displays all attributes' do
        get wrestling_event_path(wrestling_event)
        expect(response).to have_http_status(200)
        expect(response.body).to include('WrestleMania 40')
        expect(response.body).to include('WWE')
        expect(response.body).to include('2024-04-06')
        expect(response.body).to include('Lincoln Financial Field')
      end
    end

    context 'when the event does not exist' do
      it 'returns a 404 status' do
        get wrestling_event_path(id: -1)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /wrestling_events' do
    context 'when logged in' do
      before do
        post login_path, params: { session: { email: user.email, password: user.password } }
      end

      it 'creates a new wrestling_event' do
        expect do
          post wrestling_events_path, params: { wrestling_event: { title: 'New Event' } }
        end.to change(WrestlingEvent, :count).by(1)
        expect(response).to redirect_to(WrestlingEvent.last)
      end

      context 'with invalid parameters' do
        it 'does not create a new wrestling_event' do
          expect do
            post wrestling_events_path, params: { wrestling_event: { title: '' } }
          end.not_to change(WrestlingEvent, :count)
        end

        it 'renders the new template' do
          post wrestling_events_path, params: { wrestling_event: { title: '' } }
          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('New Wrestling Event')
        end
      end
    end

    context 'when not logged in' do
      it 'redirects to login path' do
        post wrestling_events_path, params: { wrestling_event: { title: 'New Event' } }
        expect(response).to redirect_to(login_path)
      end

      it 'does not create a new event' do
        expect do
          post wrestling_events_path, params: { wrestling_event: { title: 'New Event' } }
        end.not_to change(WrestlingEvent, :count)
      end
    end
  end
end
