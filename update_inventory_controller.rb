content = File.read('app/controllers/inventory_controller.rb')

new_methods = <<-METHODS

  def edit
    @resource = resource_class.find(params[:id])
    redirect_to root_url unless @resource.user == current_user || current_user.admin?
    instance_variable_set("@\#{resource_name}", @resource)
  end

  def update
    @resource = resource_class.find(params[:id])
    redirect_to root_url unless @resource.user == current_user || current_user.admin?
    instance_variable_set("@\#{resource_name}", @resource)

    respond_to do |format|
      if @resource.update(resource_params)
        format.html { redirect_to @resource, notice: "\#{resource_class.model_name.human} was successfully updated." }
      else
        format.html { render :edit, status: failure_status }
      end
    end
  end
METHODS

content = content.sub("  def show", new_methods + "\n  def show")
content = content.sub("before_action :logged_in_user, only: %i[new create]", "before_action :logged_in_user, only: %i[new create edit update]")

File.write('app/controllers/inventory_controller.rb', content)
