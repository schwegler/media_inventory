# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Approved import corrections' do
  it 'keeps corrected people and cover sources through refresh without touching reviews or refresh permissions' do
    user = User.create!(name: 'Reader', password: 'password')
    show = TvShow.create!(title: 'Corrected series', director: 'Old director')
    show.update_columns(api_id: '42', metadata_credits_data: [{ 'name' => 'Old director', 'role' => 'Director' }])
    review = LibraryItem.create!(item: show, user: user, review: 'Keep my review', rating: '4')
    MetadataRefresh.create!(item: show, provider_values: { 'director' => 'Old director' })
    suggestion = EditSuggestion.create!(suggestable: show, user: user,
                                        proposed_changes: { 'director' => 'Correct director',
                                                            'thumbnail_url' => 'https://images.example/correct.jpg' })
    Admin::ModerateSuggestion.new(suggestion, user).call('approved')
    stub_request(:get, 'https://api.tvmaze.com/shows/42').to_return(body: {
      _embedded: { crew: [{ type: 'Director', person: { name: 'Old director' } }] },
      image: { original: 'https://images.example/provider.jpg' }
    }.to_json)
    stub_request(:get, 'https://api.tvmaze.com/shows/42/episodes').to_return(body: '[]')
    expect(MetadataRefresher.call(show, user)).to eq('unchanged')
    expect(show.reload).to have_attributes(director: 'Correct director', thumbnail_url: 'https://images.example/correct.jpg')
    expect(show.metadata_entities.pluck(:name)).to include('Correct director')
    expect(show.metadata_entities.pluck(:name)).not_to include('Old director')
    expect(review.reload).to have_attributes(review: 'Keep my review', rating: '4')
  end
end
