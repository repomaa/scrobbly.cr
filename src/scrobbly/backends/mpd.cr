require "socket"
require "yaml"
require "../backend"
require "../song_info"

module Scrobbly
  module Backends
    class Mpd < Backend
      @last_song_id : Int32?

      class Config
        YAML.mapping(
          host: { type: String, default: "localhost" },
          port: { type: Int32, default: 6600 },
          password: String?
        )
      end

      class CommandError < Exception
      end

      def initialize(update_channel, config : Config)
        super(update_channel)
        @last_song_id = nil
        @socket = TCPSocket.new(config.host, config.port)
        @socket.gets("OK")
        config.password.try { |password| authenticate(password) }
        signal(Signal::SongChange, current_song)
      end

      def start
        loop do
          idle
          song_info = current_song
          signal(Signal::SongChange, song_info) if song_info != @now_playing
          update_state
        end
      end

      private def current_song
        send_command("currentsong") do |result|
          track = result[/(?<=Title: ).*/]
          album_artist = result[/(?<=AlbumArtist: ).*/]
          album = result[/(?<=Album: ).*/]
          artist = result[/(?<=Artist: ).*/]
          track_number = result[/(?<=Track: ).*/]
          duration = result[/(?<=duration: ).*/]

          SongInfo.new(
            artist: artist, track: track, album_artist: album_artist,
            album: album, track_number: track_number.to_i,
            duration: duration.to_f.seconds
          )
        end
      end

      private def send_command(command)
        @socket.puts(command)
        code = nil

        result = String.build do |io|
          loop do
            line = @socket.gets(chomp: true)

            if line =~ /^(OK$|ACK)/
              code = line
              break
            end

            io.puts(line)
          end
        end

        raise CommandError.new(result) unless code == "OK"
        yield(result)
      end

      private def send_command(command)
        send_command(command) {}
      end

      private def idle
        send_command("idle player")
      end

      private def current_state
        send_command("status") do |result|
          result[/(?<=state: ).*/]
        end
      end

      private def update_state
        case current_state
        when "play" then signal(Signal::Play) unless @state == State::Playing
        when "pause" then signal(Signal::Pause) unless @state == State::Paused
        when "stop" then signal(Signal::Stop) unless @state == State::Stopped
        end
      end

      private def authenticate(password)
        send_command("password #{password}")
      end
    end
  end
end
