require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

RSpec.describe StationsController, type: :controller do

  # This should return the minimal set of attributes required to create a valid
  # Station. As you add validations to Station, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
    skip("Add a hash of attributes valid for your model")
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # StationsController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  describe "GET #index" do
    it "assigns all stations as @stations" do
      station = Station.create! valid_attributes
      get :index, {}, valid_session
      expect(assigns(:stations)).to eq([station])
    end
  end

  describe "GET #show" do
    it "assigns the requested station as @station" do
      station = Station.create! valid_attributes
      get :show, {:id => station.to_param}, valid_session
      expect(assigns(:station)).to eq(station)
    end
  end

  # describe "GET #new" do
  #   it "assigns a new station as @station" do
  #     get :new, {}, valid_session
  #     expect(assigns(:station)).to be_a_new(Station)
  #   end
  # end


  describe "POST #create" do
    context "with valid params" do
      it "creates a new Station" do
        expect {
          post :create, {:station => valid_attributes}, valid_session
        }.to change(Station, :count).by(1)
      end

      it "assigns a newly created station as @station" do
        post :create, {:station => valid_attributes}, valid_session
        expect(assigns(:station)).to be_a(Station)
        expect(assigns(:station)).to be_persisted
      end

      it "redirects to the created station" do
        post :create, {:station => valid_attributes}, valid_session
        expect(response).to redirect_to(Station.last)
      end
    end

    context "with invalid params" do
      it "assigns a newly created but unsaved station as @station" do
        post :create, {:station => invalid_attributes}, valid_session
        expect(assigns(:station)).to be_a_new(Station)
      end

      it "re-renders the 'new' template" do
        post :create, {:station => invalid_attributes}, valid_session
        expect(response).to render_template("new")
      end
    end
  end


end
