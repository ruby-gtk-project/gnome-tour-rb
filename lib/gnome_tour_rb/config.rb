# frozen_string_literal: true

require 'shellwords'

require_relative 'paths'

module GnomeTourRb
  # The build-time constants upstream generates into `config.rs` from meson.
  # There is no build step here, so the profile comes from the environment
  # instead of a meson option — `GNOME_TOUR_RB_PROFILE=development` selects the
  # devel profile, exactly as `-Dprofile=development` does upstream.
  module Config
    BASE_ID = 'org.gnome.Tour.Rb'
    BASE_VERSION = '50.0'
    GETTEXT_PACKAGE = 'gnome-tour-rb'

    module_function

    def development? = ENV.fetch('GNOME_TOUR_RB_PROFILE', 'default') == 'development'

    # `Devel` for a development build, empty otherwise. The window adds it as
    # a style class, and it is suffixed onto the application id.
    def profile
      case development?
      when true then 'Devel'
      else ''
      end
    end

    def app_id = "#{BASE_ID}#{profile}"

    # A devel build reports the commit it was run from, the way meson stamps
    # the short SHA into the version.
    def version = "#{BASE_VERSION}#{version_suffix}"

    def version_suffix
      case development?
      when true then "-#{vcs_tag}"
      else ''
      end
    end

    def vcs_tag
      @vcs_tag ||= read_vcs_tag
    end

    def read_vcs_tag
      `git -C #{__dir__.shellescape} rev-parse --short HEAD 2>/dev/null`.strip.then do |tag|
        case tag
        when '' then 'devel'
        else tag
        end
      end
    rescue StandardError
      'devel'
    end

    # Upstream's PKGDATADIR: where the artwork, icons and stylesheet live.
    def pkgdatadir = Paths.data_dir

    def localedir = Paths.po_dir
  end
end
