# frozen_string_literal: true

# Independent forms can create independent shelves; retries of one form keep
# their existing identity. Bound pending nonces to avoid growing cookie sessions.
module ShelfCreationNonces
  private

  def issue_creation_nonce
    token = SecureRandom.hex(24)
    session[:shelf_creation_tokens] = (Array(session[:shelf_creation_tokens]) + [token]).last(10)
    token
  end

  def valid_creation_nonce?
    params[:creation_token].present? && Array(session[:shelf_creation_tokens]).include?(params[:creation_token])
  end

  def remember_creation
    session[:shelf_creation_tokens] = Array(session[:shelf_creation_tokens]) - [params[:creation_token]]
    session[:last_shelf_creation_token] = params[:creation_token]
    session[:last_shelf_creation_slug] = @collection.slug
  end
end
