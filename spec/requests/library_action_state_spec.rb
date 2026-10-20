# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Library action response state', type: :request do
  it 'renders persisted personal flags in the Turbo replacement in both directions' do
    user = User.create!(name: 'Action QA', email: 'action@example.com', password: 'password', confirmed_at: Time.current)
    movie = Movie.create!(title: 'Synthetic action test')
    library = LibraryItem.create!(user: user, item: movie)
    post login_path, params: { session: { email: user.email, password: 'password' } }

    { is_collected: 'In Collection', in_watchlist: 'On List', consumed: 'Watched' }.each do |field, label|
      [true, false, true, false].each do |value|
        patch movie_path(movie), params: { movie: { field => value } }, as: :turbo_stream
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        stored_field = field == :in_watchlist ? :in_backlog : field
        expect(library.reload.public_send(stored_field)).to eq(value)
        html = Nokogiri::HTML.fragment(response.body)
        button = html.css('.actions-buttons-row form').find { |form| form.at_css("input[name='movie[#{field}]']") }
        expect(button.at_css('button')['class'].include?('is-selected')).to eq(value), "#{field}=#{value}: #{button}"
        expect(button.at_css('button').text).to include(label) if value
        expect(button.at_css("input[name='movie[#{field}]']")['value']).to eq((!value).to_s)
      end
    end
  end
end
