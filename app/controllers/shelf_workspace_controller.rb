# frozen_string_literal: true

# Owner-only work area. Public routes remain exhibitions, including for their owner.
class ShelfWorkspaceController < ShelvesController
  include ShelfCreationNonces

  skip_before_action :load_user
  before_action :logged_in_user
  before_action :workspace_owner
  before_action :managed_collection, only: %i[edit settings update confirm_archive archive restore]
  layout 'application'

  def index
    @collections = @user.shelf_collections.active.order(:created_at).to_a
    preload_collection_items(@collections)
    @archived = @user.shelf_collections.archived.order(archived_at: :desc)
    @favorites = load_shelves_with_batch_items(@user)
  end

  def new
    @collection = @user.shelf_collections.new
    @creation_token = issue_creation_nonce
  end

  def create
    if params[:creation_token].present? && params[:creation_token] == session[:last_shelf_creation_token]
      return redirect_to edit_managed_shelf_path(session[:last_shelf_creation_slug]), status: :see_other
    end
    return head :conflict unless valid_creation_nonce?

    mood = helpers.shelf_starting_mood(params[:starting_mood])
    presentation = helpers.shelf_image_style({}).merge('theme' => mood)
    @collection = ShelfCollectionCreation.call(@user, collection_attributes, token: params[:creation_token],
                                                                             presentation: presentation)
    if @collection.persisted?
      remember_creation
      redirect_to edit_managed_shelf_path(@collection.slug), notice: 'Shelf created. Add your first titles.',
                                                             status: :see_other
    else
      @creation_token = params[:creation_token]
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @workspace_edit = true
    params[:collection] = @collection.slug
    show
  end

  def favorite
    raise ActiveRecord::RecordNotFound unless params[:category].nil? || FavoriteShelf::CATEGORIES.key?(params[:category])

    @workspace_edit = true
    show
  end

  alias appearance favorite

  def update
    @user.with_lock do
      return stale_edit unless current_version?

      if @collection.update(collection_attributes)
        redirect_to edit_managed_shelf_path(@collection.slug), notice: 'Shelf settings saved.', status: :see_other
      else
        render :settings, status: :unprocessable_content
      end
    end
  end

  def archive
    @user.with_lock do
      return stale_edit unless current_version?

      unless params[:confirmation] == @collection.title
        @collection.errors.add(:base, 'Enter the shelf title exactly to confirm archiving.')
        return render :confirm_archive, status: :unprocessable_content
      end
      @collection.update_column(:archived_at, Time.current)
      redirect_to shelf_workspace_path, notice: 'Shelf archived. You can restore it below.', status: :see_other
    end
  end

  def restore
    @user.with_lock do
      @collection.update_column(:archived_at, nil)
      redirect_to shelf_workspace_path, notice: 'Shelf restored with its original URL and selections.', status: :see_other
    end
  end

  private

  def workspace_owner
    @user = current_user
    return if @user.username.present?

    redirect_to settings_path, notice: 'Choose a username before creating shelves.'
  end

  def managed_collection
    scope = action_name == 'restore' ? @user.shelf_collections.archived : @user.shelf_collections.active
    @collection = scope.find_by!(slug: params[:slug])
  end

  def collection_attributes
    attributes = params.require(:shelf_collection).permit(:title, :description, :preview_length, allowed_media_types: [])
    attributes[:allowed_media_types] = attributes[:allowed_media_types].compact_blank if attributes[:allowed_media_types]
    attributes
  end

  def current_version?
    @collection.reload
    params[:shelf_version] == helpers.shelf_edit_version(@user, "collection:#{@collection.slug}")
  end

  def stale_edit
    @collection.errors.add(:base, 'This shelf changed in another window. Reload before saving.')
    render(action_name == 'archive' ? :confirm_archive : :settings, status: :conflict)
  end
end
