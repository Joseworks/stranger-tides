require 'rails_helper'

RSpec.describe "stations/index", type: :view do
  before(:each) do
    assign(:stations, [
      Station.create!(),
      Station.create!()
    ])
  end

  it "renders a list of stations" do
    render
  end
end
