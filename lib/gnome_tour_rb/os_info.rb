# frozen_string_literal: true

module GnomeTourRb
  # Upstream calls `glib::os_info`, which is not bound in ruby-gnome. It reads
  # the same os-release file the C function does, with the same fallbacks the
  # window applies (`GNOME`, and an empty version).
  module OsInfo
    PATHS = ['/etc/os-release', '/usr/lib/os-release'].freeze

    module_function

    def name = fields.fetch('NAME', 'GNOME')

    def version = fields.fetch('VERSION', '')

    def fields
      @fields ||= parse(PATHS.find { |path| File.exist?(path) })
    end

    def reset! = @fields = nil

    def parse(path)
      case path
      when nil then {}
      else parse_lines(File.readlines(path, encoding: 'UTF-8'))
      end
    end

    def parse_lines(lines)
      lines.filter_map { |line| line.chomp.match(/\A([A-Z0-9_]+)=(.*)\z/) }
           .to_h { |match| [match[1], unquote(match[2].strip)] }
    end

    def unquote(value)
      case value
      when /\A"(.*)"\z/m then Regexp.last_match(1).gsub(/\\(.)/, '\1')
      when /\A'(.*)'\z/m then Regexp.last_match(1)
      else value
      end
    end
  end
end
