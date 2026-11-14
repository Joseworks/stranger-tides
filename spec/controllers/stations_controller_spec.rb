# frozen_string_literal: true

require 'rails_helper'
RSpec.describe StationsController do
  it 'does not execute chart JavaScript for a non-AJAX legacy request' do
    post :show_graph, params: { content: '1617433' }, format: :js
    expect(response).to have_http_status(:gone)
    expect(response.media_type).to eq('application/json')
  end
end
