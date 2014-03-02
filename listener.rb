# This will start a thread that listens for notifications from
# postgres. You can register more than one event using 'on'. At least
# one event should be registered, otherwise the Listener does nothing.
class Listener
  def initialize(connection, logger)
    @connection = connection
    @logger = logger
    @actions = {}
  end

  # Listen for notifications for channel. On notification, the block
  # will be called in the listener thread.
  def on(channel, &block)
    @actions[channel] = block
    @connection.exec("LISTEN #{channel}")
    @logger.info "Listener listening on #{channel}"
  end

  # Start the listener thread (TODO make this unnecessary)
  def start
    Thread.new do
      loop do
        @connection.wait_for_notify do |channel|
          @actions[channel].call
        end
      end
    end
  end
end
