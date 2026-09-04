# frozen_string_literal: true

require 'logger'

require_relative 'config'

module GnomeTourRb
  # Upstream sets up `env_logger` and then, for compatibility, turns on debug
  # logging for its own module when `G_MESSAGES_DEBUG` would not have dropped
  # it. This is the same arrangement: quiet unless asked, `GNOME_TOUR_RB_LOG`
  # sets a level directly, and `G_MESSAGES_DEBUG` naming the domain (or `all`)
  # turns on debug.
  module Log
    DOMAIN = 'gnome_tour_rb'
    LEVELS = {
      'error' => Logger::ERROR,
      'warn'  => Logger::WARN,
      'info'  => Logger::INFO,
      'debug' => Logger::DEBUG,
      'trace' => Logger::DEBUG,
    }.freeze

    module_function

    def logger
      @logger ||= Logger.new($stderr, level: level, progname: DOMAIN).tap do |log|
        log.formatter = proc { |severity, _time, progname, message| "[#{severity} #{progname}] #{message}\n" }
      end
    end

    def info(message) = logger.info(message)

    def debug(message) = logger.debug(message)

    def warn(message) = logger.warn(message)

    def level
      LEVELS.fetch(ENV.fetch('GNOME_TOUR_RB_LOG', '').downcase, default_level)
    end

    # `G_MESSAGES_DEBUG` is a space-separated list of domains, or `all`.
    def default_level
      case debug_domains.include?('all') || debug_domains.include?(DOMAIN)
      when true then Logger::DEBUG
      else Logger::ERROR
      end
    end

    def debug_domains = ENV.fetch('G_MESSAGES_DEBUG', '').split

    # The three lines upstream logs on startup, before the application runs.
    def banner
      info("GNOME Tour (#{Config.app_id})")
      info("Version: #{Config.version} (#{Config.profile})")
      info("Datadir: #{Config.pkgdatadir}")
    end

    def reset!
      @logger = nil
    end
  end
end
