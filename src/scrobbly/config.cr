require "yaml"

{% begin %}
  {% backends = (env("BACKENDS") || "mpd,pipe").split(",") %}
  {% for backend in backends %}
    require "./backends/{{backend.id}}"
  {% end %}

  {% frontends = (env("FRONTENDS") || "lastfm,log").split(",") %}
  {% for frontend in frontends %}
    require "./frontends/{{frontend.id}}"
  {% end %}

  BACKENDS = {
    {% for backend in backends %}
      {{backend}}: {{"Scrobbly::Backends::#{backend.camelcase.id}".id}},
    {% end %}
  }

  FRONTENDS = {
    {% for frontend in frontends %}
      {{frontend}}: {{"Scrobbly::Frontends::#{frontend.camelcase.id}".id}},
    {% end %}
  }
{% end %}

module Scrobbly
  class Config
    class BackendConfigs
      {% begin %}
        YAML.mapping(
          {% for backend, klass in BACKENDS %}
            {{backend}}: {{klass}}::Config?,
          {% end %}
        )
      {% end %}

      def spawn
        result = [] of Backend
        {% for backend, klass in BACKENDS %}
          {{backend.id}}.try do |config|
            channel = Channel({ Frontend::Command, SongInfo }).new(1)
            result << {{klass}}.new(channel, config)
          end
        {% end %}

        result
      end
    end

    class FrontendConfigs
      {% begin %}
        YAML.mapping(
          {% for frontend, klass in FRONTENDS %}
            {{frontend}}: {{klass}}::Config?,
          {% end %}
        )
      {% end %}

      def spawn
        result = [] of Frontend
        {% for backend, klass in FRONTENDS %}
          {{backend.id}}.try do |config|
            channel = Channel({ Frontend::Command, SongInfo }).new(1)
            result << {{klass}}.new(channel, config)
          end
        {% end %}

        result
      end
    end

    YAML.mapping(
      frontends: FrontendConfigs,
      backends: BackendConfigs
    )
  end
end
