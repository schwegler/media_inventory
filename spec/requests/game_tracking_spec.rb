# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'Private game tracking', type: :request do
  let(:user) { User.create!(name: 'Player', email: 'player@example.com', password: 'password123') }
  let(:other) { User.create!(name: 'Other', email: 'other@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Portal') }
  let!(:library) { LibraryItem.create!(user: user, item: game) }
  before { post login_path, params: { session: { email: user.email, password: 'password123' } } }
  it 'creates ownership, progress and sessions through the user library and renders private controls' do
    post game_tracking_path(video_game_id: game.id),
         params: { kind: 'copy', copy: { platform: 'Windows', storefront: 'Steam', access_method: 'digital' } }
    expect(response).to have_http_status(:see_other)
    expect(library.game_copies.count).to eq(1)
    post game_tracking_path(video_game_id: game.id),
         params: { kind: 'playthrough', playthrough: { status: 'currently_playing', platform: 'Windows' } }
    playthrough = library.game_playthroughs.last
    post game_tracking_path(video_game_id: game.id),
         params: { kind: 'session', playthrough_id: playthrough.id,
                   session: { started_at: 1.hour.ago, ended_at: Time.current, notes: 'A private session' } }
    get video_game_path(game)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('A private session', 'My gaming record')
    get export_game_path(video_game_id: game.id)
    expect(JSON.parse(response.body)['playthroughs'].first['sessions'].size).to eq(1)
    expect(response.headers['Cache-Control']).to include('no-store')
  end
  it 'edits only the signed-in users owned copy' do
    copy = library.game_copies.create!(platform: 'PC', access_method: 'digital')
    patch game_progress_path(video_game_id: game.id, id: copy.id),
          params: { kind: 'copy', copy: { platform: 'Nintendo Switch', ownership_status: 'previously_owned' } }
    expect(copy.reload).to have_attributes(platform: 'Nintendo Switch', ownership_status: 'previously_owned')
    other_library = LibraryItem.create!(user: other, item: game)
    other_copy = other_library.game_copies.create!(platform: 'Xbox')
    patch game_progress_path(video_game_id: game.id, id: other_copy.id), params: { kind: 'copy', copy: { platform: 'PC' } }
    expect(response).to have_http_status(:not_found)
    expect(other_copy.reload.platform).to eq('Xbox')
  end

  it 'preserves private custom covers and rejects an alternate selection signed for another library' do
    png = File.binread(Rails.root.join('spec/fixtures/files/valid-cover.png'))
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: 'cover.png', content_type: 'image/png')
    token = Rails.application.message_verifier('game-cover-choice').generate({ library_id: library.id, blob_id: blob.id },
                                                                             expires_in: 10.minutes)
    post select_game_artwork_path(video_game_id: game.id), params: { token: token }
    expect(response).to have_http_status(:see_other)
    expect(library.reload.game_cover_image.blob_id).to eq(blob.id)
    other_library = LibraryItem.create!(user: other, item: game)
    foreign = Rails.application.message_verifier('game-cover-choice').generate(
      { library_id: other_library.id, blob_id: blob.id }, expires_in: 10.minutes
    )
    post select_game_artwork_path(video_game_id: game.id), params: { token: foreign }
    expect(response).to have_http_status(:forbidden)
  end

  it 'does not expose private journals to another user or allow cross-user session writes' do
    library.game_journal_entries.create!(body: 'Secret quest notes')
    playthrough = library.game_playthroughs.create!
    post login_path, params: { session: { email: other.email, password: 'password123' } }
    get video_game_path(game)
    expect(response.body).not_to include('Secret quest notes', 'My gaming record')
    get export_game_path(video_game_id: game.id)
    expect(response).to have_http_status(:not_found)
    post game_tracking_path(video_game_id: game.id),
         params: { kind: 'session', playthrough_id: playthrough.id,
                   session: { started_at: 1.hour.ago, ended_at: Time.current } }
    expect(response).to have_http_status(:not_found)
    expect(playthrough.game_sessions.count).to eq(0)
  end
end

RSpec.describe 'Extended private gaming records', type: :request do
  let(:user) do
    User.create!(name: 'Player', email: 'player@example.com', password: 'password123', confirmed_at: Time.current)
  end
  let(:other) { User.create!(name: 'Other', email: 'other@example.com', password: 'password123') }
  let(:game) { VideoGame.create!(title: 'Portal') }
  let!(:library) { LibraryItem.create!(user: user, item: game, is_public: true) }
  before { post login_path, params: { session: { email: user.email, password: 'password123' } } }

  it 'keeps acquisition information private and exposes only explicitly shared status on the public shelf' do
    library.game_copies.create!(platform: 'Windows', purchase_price: 29, acquisition_source: 'Secret shop',
                                notes: 'Private receipt')
    library.game_journal_entries.create!(body: 'Secret build notes')
    library.game_playthroughs.create!(status: 'currently_playing', progress: 25, notes: 'Secret route')
    get game_shelf_path(user)
    expect(response.body).not_to include('>Portal<')
    patch game_preferences_path(video_game_id: game.id),
          params: { preferences: { game_favorite: '1', game_activity_public: '1', tags: 'RPG, Favorites' } }
    expect(library.reload).to have_attributes(game_favorite: true, game_tags: %w[RPG Favorites])
    get game_shelf_path(user)
    expect(response.body).to include('>Portal<', 'Currently playing (25%)', 'Favorite game')
    expect(response.body).not_to include('Secret shop', 'Private receipt', 'Secret build notes', 'Secret route', 'RPG')
    library.update!(is_public: false)
    get game_shelf_path(user)
    expect(response.body).not_to include('>Portal<')
  end

  it 'edits sessions and journals, records manual goals and rejects cross-user changes' do
    run = library.game_playthroughs.create!
    session = run.game_sessions.create!(started_at: 1.hour.ago, ended_at: Time.current)
    patch game_progress_path(video_game_id: game.id, id: session.id),
          params: { kind: 'session', session: { enjoyment: 5, mood: 'Happy', progress: 40 } }
    expect(session.reload).to have_attributes(enjoyment: 5, mood: 'Happy', progress: 40)
    post game_tracking_path(video_game_id: game.id),
         params: { kind: 'milestone', milestone: { title: 'Beat final boss', spoiler: true } }
    milestone = library.game_milestones.last
    patch game_progress_path(video_game_id: game.id, id: milestone.id),
          params: { kind: 'milestone', milestone: { completed_at: Time.current } }
    expect(milestone.reload.completed_at).to be_present
    entry = library.game_journal_entries.create!(body: 'Original notes')
    patch game_progress_path(video_game_id: game.id, id: entry.id),
          params: { kind: 'journal', journal: { body: 'Edited notes' } }
    expect(entry.reload.body).to eq('Edited notes')
    LibraryItem.create!(user: other, item: game)
    post login_path, params: { session: { email: other.email, password: 'password123' } }
    delete delete_game_tracking_path(video_game_id: game.id, id: session.id), params: { kind: 'session' }
    expect(response).to have_http_status(:not_found)
    patch game_progress_path(video_game_id: game.id, id: milestone.id),
          params: { kind: 'milestone', milestone: { title: 'Changed' } }
    expect(response).to have_http_status(:not_found)
    expect(session.reload).to be_present
    expect(milestone.reload.title).to eq('Beat final boss')
  end
end
