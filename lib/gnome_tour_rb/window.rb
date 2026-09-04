# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'config'
require_relative 'i18n'
require_relative 'image_page'
require_relative 'os_info'
require_relative 'paginator'

module GnomeTourRb
  # The tour window: a paginator filled with the seven pages, plus the four
  # `win.` actions the navigation buttons and the Escape accelerator drive.
  class Window
    include I18n

    # Page content, in carousel order. The welcome page's body is filled in at
    # construction time from the running distribution's name and version.
    PAGES = [
      { asset: 'welcome.svg', head: "Let's Begin" },
      {
        asset: 'overview.svg',
        head:  'Get an Overview',
        body:  'The overview shows all your apps and windows. Press the Super (Windows) key to open it.',
      },
      {
        asset: 'search.svg',
        head:  'Powerful Search',
        body:  'To search, just start typing in the overview. You can use search to launch apps, ' \
               'find files, perform calculations, and more.',
      },
      {
        asset: 'workspaces.svg',
        head:  'Stay Organized With Workspaces',
        body:  'Organize your windows by moving them into different workspaces. ' \
               'This can be done by dragging them in the overview.',
      },
      {
        asset: 'blank.svg',
        head:  'Swipe Up and Down',
        body:  'To quickly open the overview with a touchpad, swipe up with three fingers.',
      },
      {
        asset: 'blank.svg',
        head:  'Swipe Left and Right',
        body:  'To move between workspaces, swipe three fingers horizontally.',
      },
      {
        asset: 'ready-to-go.svg',
        head:  "That's It!",
        body:  'To get more advice and tips, see the Help app.',
      },
    ].freeze

    attr_reader :application, :paginator, :image_pages

    def initialize(application)
      @application = application
      @paginator = Paginator.new
      @image_pages = PAGES.map { |page| build_image_page(page) }
    end

    def build
      window.tap do |win|
        win.content = paginator.build

        image_pages.each do |page|
          paginator.add_page(page.build)
        end

        welcome_page.body = welcome_body

        install_actions
      end
    end

    def present = window.present

    def welcome_page = image_pages.first

    # Translators see this as "Learn about the key features in {name}
    # {version}." — the placeholders are filled after translation.
    def welcome_body
      _('Learn about the key features in {name} {version}.')
        .gsub('{name}', OsInfo.name)
        .gsub('{version}', OsInfo.version)
    end

    def install_actions
      {
        'start-tour'    => -> { start_tour },
        'skip-tour'     => -> { application.quit },
        'next-page'     => -> { next_page },
        'previous-page' => -> { previous_page },
      }.each do |name, handler|
        window.add_action(
          Gio::SimpleAction.new(name).tap do |action|
                    action.signal_connect('activate') { handler.call }
                  end,
        )
      end
    end

    def start_tour = paginator.set_page(1)

    def reset_tour = paginator.set_page(0)

    # Past the last page there is nowhere to go, so the tour is over.
    def next_page
      case paginator.try_next
      when nil then window.close
      end
    end

    def previous_page
      case paginator.try_previous
      when nil then reset_tour
      end
    end

    def window
      @window ||= Adwaita::ApplicationWindow.new(application).tap do |win|
        win.set_default_size(960, 720)
        win.icon_name = Config.app_id

        # A development build wears the striped Adwaita header so it cannot be
        # mistaken for the installed one.
        case Config.development?
        when true then win.add_css_class('devel')
        end
      end
    end

    private

      def build_image_page(page)
        ImagePage.new(
          asset: page[:asset],
          head:  _(page[:head]),
          body:  _(page.fetch(:body, '')),
        )
      end
  end
end
