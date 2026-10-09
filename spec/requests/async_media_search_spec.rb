# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Asynchronous media search', type: :request do
  include ActiveJob::TestHelper

  it 'returns promptly without external HTTP and serves results after the job finishes' do
    expect { get '/media/autocomplete', params: { q: 'Portal', type: 'video_game', async: '1' } }
      .to have_enqueued_job(MediaSearchJob)
    expect(response).to have_http_status(:accepted)
    expect(WebMock).not_to have_requested(:get, /store.steampowered.com/)
    perform_enqueued_jobs(only: MediaSearchJob)
    get '/media/autocomplete', params: { q: 'Portal', type: 'video_game', async: '1' }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to be_an(Array)
  end
end
