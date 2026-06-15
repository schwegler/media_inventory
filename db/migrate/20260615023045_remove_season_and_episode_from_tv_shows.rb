class RemoveSeasonAndEpisodeFromTvShows < ActiveRecord::Migration[8.1]
  def change
    remove_column :tv_shows, :season, :integer
    remove_column :tv_shows, :episode, :integer
  end
end
