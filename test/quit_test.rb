# frozen_string_literal: true

# The two actions that end the application, checked by actually ending it:
# `win.skip-tour` (bound to Escape) and `app.quit` (bound to Ctrl+Q). Both are
# supposed to quit outright rather than close the window, so each needs its own
# process.
#
#   ruby test/quit_test.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir

require 'gnome_tour_rb'

$failures = 0

def check(description)
  case yield
  when true then puts "ok   #{description}"
  else
    puts "FAIL #{description}"
    $failures += 1
  end
end

# Builds the app, lets it settle, fires the action, and reports whether the
# main loop came back and `shutdown` was emitted. A watchdog quits after five
# seconds so a wiring mistake fails rather than hangs.
def run_until_quit(action_name, target)
  { shutdown: false, quit: false, timed_out: false }.tap do |result|
    GnomeTourRb::Application.new.tap do |app|
      app.build

      app.app.signal_connect('shutdown') { result[:shutdown] = true }

      app.app.signal_connect('activate') do
        GLib::Timeout.add(400) do
          result[:quit] = true
          target.call(app).activate_action(action_name, nil)
          false
        end

        GLib::Timeout.add(5_000) do
          result[:timed_out] = true
          app.app.quit
          false
        end
      end

      app.run
    end
  end
end

skip = run_until_quit('skip-tour', ->(app) { app.main_window.window })

check('win.skip-tour was reached') { skip[:quit] }
check('win.skip-tour ends the main loop') { skip[:shutdown] }
check('win.skip-tour did not need the watchdog') { !skip[:timed_out] }

quit = run_until_quit('quit', ->(app) { app.app })

check('app.quit was reached') { quit[:quit] }
check('app.quit ends the main loop') { quit[:shutdown] }
check('app.quit did not need the watchdog') { !quit[:timed_out] }

puts
case $failures
when 0 then puts 'all checks passed'
else
  puts "#{$failures} check(s) failed"
  exit 1
end
