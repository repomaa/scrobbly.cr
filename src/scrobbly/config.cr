require "yaml"

{% begin %}
  {% backend_whitelist = (env("WITH_BACKENDS") || "mpd,pipe").split(",") %}
  {% backend_blacklist = (env("WITHOUT_BACKENDS") || "").split(",") %}
  {% backends = backend_whitelist.reject { |backend| backend_blacklist.includes?(backend) } %}

  {% for backend in backends %}
    require "./backends/{{backend.id}}"
  {% end %}

  {% frontend_whitelist = (env("WITH_BACKENDS") || "lastfm,log").split(",") %}
  {% frontend_blacklist = (env("WITHOUT_BACKENDS") || "").split(",") %}
  {% frontends = frontend_whitelist.reject { |frontend| frontend_blacklist.includes?(frontend) } %}
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
