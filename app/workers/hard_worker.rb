class HardWorker
  include Sidekiq::Worker
  def perform(name, count)
    # do something
    p "==============#{name}"
  end
end