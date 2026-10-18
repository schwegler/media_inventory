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

RSpec.describe 'Corrections to imported provider facts' do
  it 'protects individual corrected facts and refreshes unrelated facts while preserving numeric and list types' do
    user = User.create!(name: 'Reader', password: 'password')
    movie = Movie.create!(title: 'My movie', metadata_details: { 'Runtime' => 90, 'Languages' => ['English'] })
    movie.update_columns(api_id: 'itunes_42')
    suggestion = EditSuggestion.create!(suggestable: movie, user: user, proposed_changes: {
                                          'metadata_details' => { 'Runtime' => '100', 'Languages' => "English\nFrench" }
                                        })
    Admin::ModerateSuggestion.new(suggestion, user).call('approved')
    expect(movie.reload.metadata_details).to eq('Runtime' => 100, 'Languages' => %w[English French])
    adapter = instance_double(MetadataProvider, partial: false, provider: 'iTunes',
                                                call: [{ metadata_details: { 'Runtime' => 120,
                                                                             'Languages' => ['German'],
                                                                             'description' => 'New synopsis' } }, []])
    allow(MetadataProvider).to receive(:new).and_return(adapter)
    expect(MetadataRefresher.call(movie, user)).to eq('success')
    expect(movie.reload.metadata_details).to eq('Runtime' => 100, 'Languages' => %w[English French],
                                                'description' => 'New synopsis')
  end

  it 'rejects internal keys and malformed nested values without changing the catalog' do
    user = User.create!(name: 'Reader', password: 'password')
    game = VideoGame.create!(title: 'Game', metadata_details: { 'genres' => ['Adventure'] })
    [{ 'related_steam_dlc_ids' => [999] }, { 'genres' => { 'injected' => 'nested' } }].each do |details|
      suggestion = EditSuggestion.create!(suggestable: game, user: user,
                                          proposed_changes: { 'metadata_details' => details })
      expect { Admin::ModerateSuggestion.new(suggestion, user).call('approved') }
        .to raise_error(Admin::ModerateSuggestion::InvalidDecision)
      expect(suggestion.reload.status).to eq('pending')
      expect(game.reload.metadata_details).to eq('genres' => ['Adventure'])
    end
  end
end

RSpec.describe 'Correction protection in game enrichment' do
  it 'keeps cleared credits, corrected classifications and genre categories through queued enrichment and refresh' do
    user = User.create!(name: 'Reader', password: 'password')
    game = VideoGame.create!(title: 'A corrected game', developer: 'Old studio', game_type: 'game',
                             metadata_details: { 'genres' => ['Old genre'] },
                             metadata_credits_data: [{ 'name' => 'Old studio', 'role' => 'Developer' },
                                                     { 'name' => 'Old genre', 'role' => 'Genre', 'kind' => 'genre' }])
    game.update_columns(api_id: 'steam_42')
    suggestion = EditSuggestion.create!(suggestable: game, user: user, proposed_changes: {
                                          'developer' => '', 'game_type' => 'unknown',
                                          'metadata_details' => { 'genres' => 'Correct genre' }
                                        })
    Admin::ModerateSuggestion.new(suggestion, user).call('approved')
    adapter = instance_double(MetadataProvider, partial: false, provider: 'Steam', call: [{
                                developer: 'Old studio', game_type: 'dlc', metadata_details: { 'genres' => ['Old genre'] },
                                metadata_credits_data: [{ 'name' => 'Old studio', 'role' => 'Developer' },
                                                        { 'name' => 'Old genre', 'role' => 'Genre', 'kind' => 'genre' }]
                              }, []])
    allow(MetadataProvider).to receive(:new).and_return(adapter)
    EnrichVideoGameJob.perform_now(game)
    MetadataRefresh.find_by!(item: game).update!(requested_at: nil)
    MetadataRefresher.call(game, user)
    expect(game.reload).to have_attributes(developer: '', game_type: 'unknown')
    expect(game.metadata_details['genres']).to eq(['Correct genre'])
    expect(game.metadata_entities.pluck(:name)).to include('Correct genre')
    expect(game.metadata_entities.pluck(:name)).not_to include('Old studio', 'Old genre')
  end
end
