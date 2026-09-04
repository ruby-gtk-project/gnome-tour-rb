# frozen_string_literal: true

# The command line reaches GApplication. It is easy to lose — an empty argv
# makes the app run normally whatever it was asked to do, so the desktop
# entry's DBusActivatable would launch a full window instead of a service.
#
#   ruby test/cli_test.rb

require 'open3'

$failures = 0

def check(description)
  case yield
  when true then puts "ok   #{description}"
  else
    puts "FAIL #{description}"
    $failures += 1
  end
end

LAUNCHER = File.expand_path('../bin/gnome-tour-rb', __dir__)

def launch(*args)
  Open3.capture3(
    { 'DISPLAY' => nil, 'WAYLAND_DISPLAY' => nil },
    RbConfig.ruby,
    LAUNCHER,
    *args,
  )
end

out, _err, status = launch('--help')

check('--help exits cleanly') { status.success? }
check('--help prints a usage line') { out.include?('Usage:') }
check('--help is titled with the application name') { out.include?('Tour [OPTION') }
check('--help lists the GApplication options') { out.include?('--help-gapplication') }

_out, err, status = launch('--no-such-option')

check('an unknown option fails') { !status.success? }
check('an unknown option is named in the error') { err.include?('--no-such-option') }

puts
case $failures
when 0 then puts 'all checks passed'
else
  puts "#{$failures} check(s) failed"
  exit 1
end
