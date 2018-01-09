require "../backend"

module Scrobbly
  module Backends
    class Pipe < Backend
      class Config
        def self.new(parser, node)
          new
        end
      end

      def initialize(update_channel, config)
        super(update_channel)
      end

      def start
        loop do
          line = STDIN.gets
          break unless line
          signal(Signal::SongChange, SongInfo.from_json(line))
        end
      end
    end
  end
end
