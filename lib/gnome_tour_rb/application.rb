# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'i18n'
require_relative 'paths'
require_relative 'window'

module GnomeTourRb
  # The application: one window, the quit action, and the two accelerators.
  # Upstream loads its stylesheet, icons and artwork from a GResource; this
  # port registers the same files from `data/` instead.
  class Application
    include I18n

    APP_ID = Window::APP_ID

    def build
      app.tap do |a|
        a.signal_connect('startup') do
          # Without this libadwaita never loads its stylesheet, so `title-1`,
          # `circular` and the Adwaita colour scheme all silently do nothing.
          # AdwApplication would have done it; a Gtk::Application does not.
          Adwaita.init

          register_icons
          load_stylesheet
          install_quit_action

          a.set_accels_for_action('app.quit', ['<Control>q'])
          a.set_accels_for_action('win.skip-tour', ['Escape'])
        end

        # Re-activating raises the window that is already up rather than
        # building a second one on top of it.
        a.signal_connect('activate') do
          case a.active_window
          when nil then main_window.build
          end

          main_window.present
        end
      end
    end

    def run = app.run([])

    # One window only: re-activating the app raises the existing one.
    def main_window = @main_window ||= Window.new(app)

    def register_icons
      Gtk::IconTheme.get_for_display(Gdk::Display.default)
                    .add_search_path(Paths.icon_dir)
    end

    # The stylesheet points at the animation artwork by absolute path, since
    # there is no GResource to resolve `/org/gnome/Tour/...` against.
    def load_stylesheet
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        css_provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end

    # `url()` in a provider loaded from a string has no base to resolve
    # against, so the artwork is referenced by absolute file URI.
    def stylesheet_source
      File.read(Paths.stylesheet).gsub('@ASSETS@', "file://#{File.join(Paths.data_dir, 'assets')}")
    end

    def install_quit_action
      app.add_action(
        Gio::SimpleAction.new('quit').tap do |action|
                action.signal_connect('activate') { app.quit }
              end,
      )
    end

    def app
      @app ||= Gtk::Application.new(APP_ID, :default_flags).tap do |a|
        a.resource_base_path = '/org/gnome/Tour'
      end
    end

    def css_provider
      @css_provider ||= Gtk::CssProvider.new.tap do |provider|
        provider.load(data: stylesheet_source)
      end
    end
  end
end
