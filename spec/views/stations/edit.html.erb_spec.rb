require 'rails_helper'

RSpec.describe "stations/edit", type: :view do
  before(:each) do
    @station = assign(:station, Station.create!())
  end

  it "renders the edit station form" do
    render

    assert_select "form[action=?][method=?]", station_path(@station), "post" do
    end
  end
end
