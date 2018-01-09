module Scrobbly
  class Timer
    enum Control
      Start
      Stop
      Reset
      Tick
      Destroy
    end

    enum State
      Running
      Stopped
      Destroyed
    end

    @duration : Time::Span

    def initialize(@target : Time::Span, @notification : Channel(Bool))
      @control = Channel(Control).new(1)
      @state = State::Stopped
      @duration = 0.seconds
      spawn { runner }
      spawn { ticks }
    end

    def finalize
      @control.send(Control::Destroy)
    end

    def start
      @control.send(Control::Start)
    end

    def stop
      @control.send(Control::Stop)
    end

    def reset
      stop
      @control.send(Control::Reset)
    end

    def running?
      @state == State::Running
    end

    private def runner
      loop do
        case @control.receive
        when Control::Start then @state = State::Running
        when Control::Stop then @state = State::Stopped
        when Control::Reset then @duration = 0.seconds
        when Control::Tick
          next unless running?
          @duration += 1.second
          if @duration > @target
            stop
            @notification.send(true)
          end
        when Control::Destroy
          @state = State::Destroyed
          break
        end
      end
    end

    private def ticks
      loop do
        sleep 1
        break if @state == State::Destroyed
        @control.send(Control::Tick)
      end
    end
  end
end
