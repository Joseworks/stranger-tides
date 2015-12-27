# spec/lib/tasks/station_list.rb
describe "station_list:delete_station_list" do
  include_context "rake"

  let(:station)          { stub("station") }

  before do
    Station.stubs(:new => station)
  end

  its(:prerequisites) { should include("environment") }

  it "deletes alll stations" do
    subject.invoke
    # ReportGenerator.should have_received(:generate).with("users", csv)
  end
end


