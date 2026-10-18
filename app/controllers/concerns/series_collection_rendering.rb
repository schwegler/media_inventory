# frozen_string_literal: true

module SeriesCollectionRendering
  extend ActiveSupport::Concern

  private

  def render_series_frame
    render partial: 'shared/series_collection', locals: { item: @resource }
  end

  def prepare_series_collection(series, library)
    @series_collection = SeriesCollection.new(series, user: current_user, library: library, params: params)
    @series_library_item = library
    @child_library_items = @series_collection.libraries
    @active_pass = @series_collection.pass
    @active_pass_entry_ids = @series_collection.entry_ids
    return unless @active_pass&.active? && action_name == 'show' && !turbo_frame_request?

    @next_series_entry = NextSeriesEntry.new(series, @active_pass).next_item
  end

  def render_series_collection(series, library)
    prepare_series_collection(series, library)
    render turbo_stream: turbo_stream.replace('series-entries',
                                              partial: 'shared/series_collection', locals: { item: series })
  end
end
