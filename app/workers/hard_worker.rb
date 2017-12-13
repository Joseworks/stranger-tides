class HardWorker
  include Sidekiq::Worker
  def perform(name, count)
  end
end
