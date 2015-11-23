require 'rails_helper'

RSpec.describe "stations/new", type: :view do
  before(:each) do
    assign(:station, Station.new())
  end

  it "renders new station form" do
    render

    assert_select "form[action=?][method=?]", stations_path, "post" do
    end
  end
end
