require "./scrobbly/*"

module Scrobbly
  config_home = ENV.fetch("XDG_CONFIG_HOME", File.join(ENV["HOME"], ".config"))
  config_path = File.join(config_home, "scrobbly", "config.yml")
  unless File.exists?(config_path)
    puts "Generating default config in #{config_path}"

    Dir.mkdir_p(File.dirname(config_path))
    File.open(config_path, "w+") do |file|
      file.print({{ run("./generate_config").stringify }})
    end
  end

  config = Config.from_yaml(File.read(config_path))
  broadcast_channel = Channel({ Frontend::Command, SongInfo }).new(1)
  backends = config.backends.spawn
  frontends = config.frontends.spawn

  backends.each { |backend| puts "Spawning #{backend.class}" }
  frontends.each { |frontend| puts "Spawning #{frontend.class}" }

  spawn do
    loop do
      signal = broadcast_channel.receive
      frontends.each do |frontend|
        frontend.channel.send(signal)
      end
    end
  end

  backends.each do |backend|
    spawn do
      broadcast_channel.send(backend.channel.receive)
    end
  end

  backends.each(&.start)
end
