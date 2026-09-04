# frozen_string_literal: true

# Drives the tour window: walks the carousel forward and back through the same
# actions the buttons and the key controller trigger, and checks that the
# navigation buttons fade in and out the way upstream's do.
#
#   ruby test/drive_tour.rb
#
# Runs headlessly — GTK4 renders to an offscreen surface, so the screenshots in
# tmp/shots are what a real session would show.

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir

require 'gnome_tour_rb'
require_relative 'gtk_driver'

# The carousel scrolls on a spring, and the two swipe pages animate their
# backgrounds forever, which on a software-rendered offscreen surface slows
# frames down well past the driver's tick. So rather than assume one tick is
# enough, pump the main loop until the carousel has actually arrived.
def settle(paginator, page_nr, seconds: 20)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds

  until (paginator.carousel.position - page_nr).abs < 0.01
    if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      break
    end

    GLib::MainContext.default.iteration(false)
  end

  paginator.carousel.position
end

app = GnomeTourRb::Application.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _app|
  window = -> { app.main_window }
  paginator = -> { app.main_window.paginator }

  d.step('the window builds with all seven pages') do
    d.check('7 pages in the carousel') { paginator.call.carousel.n_pages == 7 }
    d.check('starts on the welcome page') { paginator.call.current_page.zero? }
    d.check('welcome heading is set') { window.call.welcome_page.head_label.label == "Let's Begin" }
    d.check('welcome body names the running OS') do
      window.call.welcome_page.body_label.label.include?(GnomeTourRb::OsInfo.name)
    end
  end

  d.window { window.call.window }

  d.step('the window and app actions are installed') do
    d.check('four win. actions') do
      %w[start-tour skip-tour next-page previous-page].all? { |name| window.call.window.has_action?(name) }
    end
    d.check('Escape skips the tour') { app.app.get_accels_for_action('win.skip-tour') == ['Escape'] }
    d.check('Ctrl+Q quits') { app.app.get_accels_for_action('app.quit') == ['<Control>q'] }
  end

  d.step('on the welcome page only the start button is shown') do
    d.check('start visible') { paginator.call.start_button.visible? }
    d.check('start is targetable') { paginator.call.start_button.can_target? }
    d.check('next hidden') { !paginator.call.next_button.visible? }
    d.check('previous hidden') { !paginator.call.previous_button.visible? }
    d.shot('01-welcome')
  end

  d.step('win.start-tour moves to the second page') do
    window.call.window.activate_action('start-tour', nil)
    settle(paginator.call, 1)

    d.check('on page 1') { paginator.call.current_page == 1 }
    d.check('heading is the overview page') do
      window.call.image_pages[1].head_label.label == 'Get an Overview'
    end
    d.check('next visible') { paginator.call.next_button.visible? }
    d.check('previous visible') { paginator.call.previous_button.visible? }
    # The spring approaches the page asymptotically, so `start` is still a
    # hair above zero opacity here; what matters is that it has faded out.
    d.check('start faded out') { paginator.call.start_button.opacity < 0.05 }
    d.shot('02-overview')
  end

  (2..6).each do |page_nr|
    d.step("win.next-page walks to page #{page_nr}") do
      window.call.window.activate_action('next-page', nil)
      settle(paginator.call, page_nr)

      d.check("on page #{page_nr}") { paginator.call.current_page == page_nr }
    end
  end

  d.step('the last page has arrived') do
    d.check('heading is the closing page') do
      window.call.image_pages[6].head_label.label == "That's It!"
    end
    d.check('next is no longer targetable') { !paginator.call.next_button.can_target? }
    d.shot('03-last')
  end

  d.step('the Left arrow key steps back onto the swipe page') do
    paginator.call.on_key_pressed(Gdk::Keyval::KEY_Left)
    settle(paginator.call, 5)

    d.check('on page 5') { paginator.call.current_page == 5 }
    # This page paints its hand-and-arrows artwork as an animated CSS
    # background, which is the one thing on screen that is not a widget.
    d.shot('04-swipe-left-right')
  end

  d.step('the Right arrow key steps forward again') do
    paginator.call.on_key_pressed(Gdk::Keyval::KEY_Right)
    settle(paginator.call, 6)

    d.check('on page 6') { paginator.call.current_page == 6 }
    d.check('try_next reports the end of the tour') { paginator.call.try_next.nil? }
  end

  6.downto(1) do |page_nr|
    d.step("win.previous-page walks back to page #{page_nr - 1}") do
      window.call.window.activate_action('previous-page', nil)
      settle(paginator.call, page_nr - 1)

      d.check("on page #{page_nr - 1}") { paginator.call.current_page == page_nr - 1 }
    end
  end

  d.step('a development build wears the devel header') do
    ENV['GNOME_TOUR_RB_PROFILE'] = 'development'

    begin
      # Built, not presented, and deliberately not destroyed: tearing down an
      # AdwApplicationWindow that was never presented segfaults the bindings.
      GnomeTourRb::Window.new(app.app).window.tap do |devel_window|
        d.check('devel style class') { devel_window.css_classes.include?('devel') }
        d.check('devel icon name') { devel_window.icon_name == 'org.gnome.Tour.RbDevel' }
      end
    ensure
      ENV['GNOME_TOUR_RB_PROFILE'] = nil
    end

    d.check('the default build does not') { !window.call.window.css_classes.include?('devel') }
  end

  d.step('back at the start') do
    d.check('try_previous reports the start of the tour') { paginator.call.try_previous.nil? }
    d.check('start button is back') { paginator.call.start_button.visible? }
    d.check('previous button is hidden again') { !paginator.call.previous_button.visible? }
    d.shot('05-back-at-welcome')
  end

end
