# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryController, type: :controller do
  # rubocop:disable Naming/PredicateMethod
  let(:dummy_model) do
    Class.new do
      include ActiveModel::Model

      attr_accessor :id, :user, :title

      def self.page(_page)
        [:page_data]
      end

      def self.find(id)
        new(id:)
      end

      def save
        if title.nil?
          errors.add(:title, "can't be blank")
          return false
        end
        self.id = 1 # Mock assignment of ID upon save
        true
      end

      def to_model
        self
      end

      def persisted?
        id.present?
      end

      def model_name
        ActiveModel::Name.new(self, nil, 'Comic')
      end
    end
  end
  # rubocop:enable Naming/PredicateMethod

  # We use testing base behavior via ComicsController to avoid routing issues with
  # AnonymousController routing
  describe 'controller actions via ComicsController' do
    controller(ComicsController) do
      # Override the private methods to use our DummyModel to avoid DB calls
      # and easily control behavior
      def resource_class
        DummyModel
      end

      def resource_name
        'comic'
      end

      def resource_params
        params.require(:comic).permit(:title)
      end

      # We have to skip the before_action since it requires login
      skip_before_action :logged_in_user
    end

    before do
      stub_const('DummyModel', dummy_model)
    end

    describe 'GET #index' do
      it 'assigns @resources and specific pluralized instance variable' do
        get :index
        expect(controller.instance_variable_get(:@resources)).to eq([:page_data])
        expect(controller.instance_variable_get(:@comics)).to eq([:page_data])
        expect(response).to have_http_status(:success)
      end
    end

    describe 'GET #new' do
      it 'assigns a new resource and specific instance variable' do
        get :new
        expect(controller.instance_variable_get(:@resource)).to be_a(DummyModel)
        expect(controller.instance_variable_get(:@comic)).to be_a(DummyModel)
        expect(response).to have_http_status(:success)
      end
    end

    describe 'GET #show' do
      it 'assigns the requested resource and specific instance variable' do
        get :show, params: { id: '1' }

        resource = controller.instance_variable_get(:@resource)
        expect(resource).to be_a(DummyModel)
        expect(resource.id).to eq('1')

        comic_var = controller.instance_variable_get(:@comic)
        expect(comic_var).to be_a(DummyModel)
        expect(comic_var.id).to eq('1')

        expect(response).to have_http_status(:success)
      end
    end

    describe 'POST #create' do
      let(:user) { double('User') }

      before do
        allow(controller).to receive(:current_user).and_return(user)
      end

      context 'with valid params' do
        it 'creates a new resource, assigns user, and redirects' do
          post :create, params: { comic: { title: 'Test Title' } }

          resource = controller.instance_variable_get(:@resource)
          expect(resource).to be_a(DummyModel)
          expect(resource.title).to eq('Test Title')
          expect(resource.user).to eq(user)

          # Since it's comics controller, it redirects to the comic
          expect(response).to redirect_to(comic_url(resource))
        end
      end

      context 'with invalid params' do
        it 'fails to save and renders new with unprocessable_content status' do
          # Stub out the render method to avoid missing template error
          # We just care about the status and that it renders new
          allow(controller).to receive(:render).and_call_original

          # We need to expect that render is called with :new since render_template
          # requires rails-controller-testing gem
          expect(controller).to receive(:render).with(:new, status: :unprocessable_content).and_call_original

          begin
            post :create, params: { comic: { title: nil } }
          rescue ActionView::MissingTemplate
            # This is expected since we don't have views for our DummyModel
          end

          resource = controller.instance_variable_get(:@resource)
          expect(resource.errors).not_to be_empty
        end
      end
    end
  end

  describe 'private methods' do
    # For private methods of InventoryController we can test an unmodified instance
    let(:unmodified_controller) { described_class.new }

    describe '#resource_class' do
      it 'constantizes the controller name' do
        allow(unmodified_controller).to receive(:controller_name).and_return('albums')
        expect(unmodified_controller.send(:resource_class)).to eq(Album)
      end
    end

    describe '#resource_name' do
      it 'singularizes the controller name' do
        allow(unmodified_controller).to receive(:controller_name).and_return('albums')
        expect(unmodified_controller.send(:resource_name)).to eq('album')
      end
    end

    describe '#failure_status' do
      it 'returns :unprocessable_content' do
        expect(unmodified_controller.send(:failure_status)).to eq(:unprocessable_content)
      end
    end

    describe '#resource_params' do
      it 'raises NotImplementedError' do
        expect { unmodified_controller.send(:resource_params) }.to raise_error(NotImplementedError)
      end
    end
  end
end
