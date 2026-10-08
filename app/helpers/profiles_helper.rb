# frozen_string_literal: true

module ProfilesHelper
  PROFILE_MEDIA_TYPES = { 'Movie' => 'Movies', 'TvShow' => 'TV shows', 'Album' => 'Albums',
                          'Comic' => 'Comics', 'Book' => 'Books', 'VideoGame' => 'Games' }.freeze

  def profile_tab_path(tab, type: nil)
    user_path(@user, tab: tab, type: type, preview: params[:preview] == 'public' ? 'public' : nil)
  end
end
