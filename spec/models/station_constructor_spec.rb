require 'rails_helper'

RSpec.describe StationConstructor, type: :model do

describe StationConstructor do
  it "has a valid factory" do
       expect(FactoryGirl.create(:station)).to be_valid
  end


  # it "has a valid station"
  # it "has a valid product"
  # it "has a valid begin_date"
  # it "has a valid begin_time"
  # it "has a valid end_date"
  # it "has a valid end_time"
  # it "has a valid datum"
  # it "has a valid units"
  # it "has a valid time_zone"
  # it "has a valid application"
  # it "has a valid format"

  # it "is invalid without a missing attribute"
end

  # describe StationConstructor::url_constructor do
    # it "returns a url as a string"
  # end



end
