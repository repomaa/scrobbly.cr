require "http/client"
require "digest/md5"
require "json"
require "../frontend"

module Scrobbly
  module Frontends
    class Lastfm < Frontend
      API_KEY = {{ env("LASTFM_API_KEY") || raise("Please set the LASTFM_API_KEY env var") }}
      API_SECRET = {{ env("LASTFM_API_SECRET") || raise("Please set the LASTFM_API_SECRET env var") }}
      API_URI = URI.parse("https://ws.audioscrobbler.com")
      API_BASE_PATH = "/2.0"

      class Config
        def self.new(parser, node)
          new
        end
      end

      class Error
        JSON.mapping(error: Int32, message: String)
      end

      class TokenResponse
        JSON.mapping(token: String)
      end

      class SessionResponse
        class Session
          JSON.mapping(key: String)
        end

        JSON.mapping(session: Session)
      end

      private getter :session_key, :client

      @session_key : String

      def initialize(notifications, config)
        @client = HTTP::Client.new(API_URI)
        @session_key = fetch_session_key
        super(notifications)
      end

      protected def scrobble(song_info : SongInfo)
        authorized_request("track.scrobble", track_params(song_info))
      end

      protected def now_playing(song_info : SongInfo)
        authorized_request("track.updateNowPlaying", track_params(song_info))
      end

      private def track_params(song_info : SongInfo)
        {
          "artist" => song_info.artist,
          "track" => song_info.track,
          "timestamp" => song_info.timestamp.epoch,
          "album" => song_info.album,
          "trackNumber" => song_info.track_number,
          "mbid" => song_info.mbid,
          "albumArtist" => song_info.album_artist,
          "duration" => song_info.duration.try(&.total_seconds).try(&.to_i),
        }
      end

      private def fetch_session_key
        cache_path = ENV.fetch("XDG_CACHE_HOME", File.join(ENV["HOME"], ".cache"))
        key_path = File.join(cache_path, "scrobbly", "lastfm_session_key")
        return File.read(key_path) if File.exists?(key_path)

        token = fetch_token
        request_authorization(token)

        request("GET", "auth.getSession", { "token" => token }) do |body|
          response = SessionResponse.from_json(body)
          response.session.key.tap do |key|
            Dir.mkdir_p(File.dirname(key_path))
            File.write(key_path, key)
          end
        end
      end

      private def request_authorization(token)
        puts "Please grant access to scrobbly by visiting the following link:"
        puts "https://www.last.fm/api/auth?api_key=#{API_KEY}&token=#{token}"
        puts "Hit enter when you've granted access"
        gets
      end

      private def fetch_token
        request("GET", "auth.getToken") do |body|
          response = TokenResponse.from_json(body)
          response.token
        end
      end

      private def authorized_request(method, params = {} of String => String)
        request("POST", method, params.merge({ "sk" => session_key })) do |body|
          yield body
        end
      end

      private def authorized_request(method, params = {} of String => String)
        authorized_request(method, params) { |body| body.close }
      end

      private def request(http_method, method, params = {} of String => String)
        request_params = request_params(method, params)
        path = API_BASE_PATH
        body = nil
        headers = HTTP::Headers.new

        if http_method == "GET"
          path += "?#{request_params}"
        else
          body = request_params
          headers.add("Content-Type", "application/x-www-form-urlencoded")
        end

        client.exec(http_method, path, headers, body) do |response|
          response_body = response.body_io.not_nil!
          return yield(response_body) if response.success?
          error = Error.from_json(response_body)
          raise error.message
        end
      end

      private def request_params(method, params)
        params = params.merge({ "api_key" => API_KEY })
        params["method"] = method
        params["api_sig"] = sign(params)
        params["format"] = "json"

        HTTP::Params.build do |builder|
          params.each do |key, value|
            builder.add(key, value.to_s) if value
          end
        end
      end

      private def sign(params)
        sorted_keys = params.keys.sort
        Digest::MD5.hexdigest do |md5|
          sorted_keys.each do |key|
            params[key].try do |value|
              md5.update(key)
              md5.update(value.to_s)
            end
          end

          md5.update(API_SECRET)
        end
      end
    end
  end
end
