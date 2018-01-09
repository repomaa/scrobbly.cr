module Scrobbly
  abstract class Frontend
    enum Command
      NowPlaying
      Scrobble
    end

    getter :channel

    def initialize(@channel : Channel({ Command, SongInfo }))
      spawn { event_loop }
    end

    private def event_loop
      loop do
        command, song_info = @channel.receive
        case command
        when Command::Scrobble
          puts "Scrobbling: #{song_info.to_s}"
          scrobble(song_info)
        when Command::NowPlaying
          puts "Updating now playing: #{song_info.to_s}"
          now_playing(song_info)
        end
      end
    end

    protected abstract def scrobble(song_info : SongInfo)
    protected abstract def now_playing(song_info : SongInfo)
  end
end
