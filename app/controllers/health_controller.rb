# frozen_string_literal: true

class HealthController < ApplicationController
  def catalog
    catalog = Noaa::Catalog.new
    status = catalog.status
    healthy = !status[:stale] && catalog.stations.any?
    response.headers['Cache-Control'] = 'no-store'
    render json: { status: healthy ? 'ok' : 'attention_required',
                   refreshed_at: status[:refreshed_at], checked_at: Time.current.iso8601 },
           status: healthy ? :ok : :service_unavailable
  end
end
