require "./song_info"
require "./frontend"
require "./timer"

module Scrobbly
  abstract class Backend
    @now_playing : SongInfo?
    @channel : Channel({ Frontend::Command, SongInfo })
    @timer : Timer?

    enum Signal
      SongChange
      Play
      Pause
      Stop
    end

    enum State
      Playing
      Paused
      Stopped
    end

    getter! :timer, :now_playing
    getter :channel

    def initialize(@channel)
      @signals = Channel({ Signal, SongInfo? }).new(1)
      @timer_signals = Channel(Bool).new(1)
      @state = State::Stopped
      spawn { signal_loop }
      spawn { timer_loop }
    end

    abstract def start

    protected def signal(signal_type, song_info = nil)
      @signals.send({ signal_type, song_info })
    end

    private def signal_loop
      loop do
        signal, song_info = @signals.receive
        case signal
        when Signal::SongChange then on_song_change(song_info.not_nil!)
        when Signal::Play then on_play
        when Signal::Pause then on_pause
        when Signal::Stop then on_stop
        end
      end
    end

    private def timer_loop
      loop do
        @timer_signals.receive
        @channel.send({ Frontend::Command::Scrobble, now_playing })
      end
    end

    private def on_song_change(song_info)
      return if @now_playing == song_info
      @timer.try(&.stop)
      @now_playing = song_info
      @channel.send({ Frontend::Command::NowPlaying, song_info })
      return if (song_info.duration || 40.seconds) < 30.seconds

      timer_target = {
        song_info.duration.try { |duration| duration / 2 } || 5.minutes,
        4.minutes
      }.min
      setup_timer(timer_target).start
    end

    private def on_play
      @state = State::Playing
      timer.start
    end

    private def on_pause
      @state = State::Paused
      timer.stop
    end

    private def on_stop
      @state = State::Stopped
      timer.reset
    end

    private def setup_timer(duration)
      @timer = Timer.new(duration, @timer_signals)
    end
  end
end
