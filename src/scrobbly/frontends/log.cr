require "yaml"
require "../frontend"

module Scrobbly
  module Frontends
    class Log < Frontend
      class Config
        YAML.mapping(
          path: String?
        )
      end

      @path : String?
      @io : IO?

      def initialize(channel, config)
        @path = config.path
        super(channel)
      end

      protected def scrobble(song_info : SongInfo)
        io.puts "Scrobbling: #{song_info.to_s}"
      end

      protected def now_playing(song_info : SongInfo)
        io.puts "Now playing: #{song_info.to_s}"
      end

      def io
        @io ||= @path.try { |path| File.open(path, "a+") } || STDOUT
      end

      def finalize
        io.close
      end
    end
  end
end
