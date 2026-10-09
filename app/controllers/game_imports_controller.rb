# frozen_string_literal: true

class GameImportsController < ApplicationController
  before_action :logged_in_user

  def new; end

  def preview
    upload = params.require(:file)
    raise GameCollectionImport::Invalid, 'Import exceeds 1 MB' if upload.size > GameCollectionImport::MAX_BYTES

    @data = GameCollectionImport.preview(upload.read, format: params[:format])
    @token = SecureRandom.hex(24)
    MediaSources::Registry::CACHE.write(['game-import', current_user.id, @token], @data, expires_in: 10.minutes)
    render :preview
  rescue GameCollectionImport::Invalid => e
    redirect_to new_game_import_path, alert: e.message
  end

  def create
    data = MediaSources::Registry::CACHE.read(['game-import', current_user.id, params[:token]])
    return head :unprocessable_content unless data

    library = GameCollectionImport.apply(current_user, data)
    MediaSources::Registry::CACHE.delete(['game-import', current_user.id, params[:token]])
    redirect_to video_game_path(library.item), notice: 'Import complete. Existing personal data was preserved.',
                                               status: :see_other
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    redirect_to new_game_import_path, alert: 'Import could not be applied. No partial records were saved.'
  end
end
