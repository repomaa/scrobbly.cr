require "yaml"
require "json"
require "./core_ext/time/span"

module Scrobbly
  record(
    SongInfo,
    artist : String,
    track : String,
    timestamp : Time = Time.now,
    album : String? = nil,
    track_number : Int32? = nil,
    mbid : String? = nil,
    album_artist : String? = nil,
    duration : Time::Span? = nil,
  ) do
    module TimeSpanConverter
      def self.from_json(parser)
        parser.read?(Float64).try(&.seconds)
      end
    end

    JSON.mapping(
      artist: String,
      track: String,
      timestamp: { type: Time, default: Time.now },
      album: String?,
      track_number: Int32?,
      mbid: String?,
      album_artist: String?,
      duration: { type: Time::Span?, converter: TimeSpanConverter }
    )

    def ==(other : SongInfo)
      {% for field in @type.instance_vars %}
        {% unless field.stringify == "timestamp" %}
          return false unless {{ field.id }} == other.{{ field.id }}
        {% end %}
      {% end %}

      return true
    end

    def to_s
      "#{artist} - #{track}"
    end
  end
end
