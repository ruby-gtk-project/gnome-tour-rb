# frozen_string_literal: true

# Plain checks on the build-profile constants, the logger's level rules and the
# desktop/metainfo translation merge.
#
#   ruby test/config_test.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'logger'

require 'gnome_tour_rb/config'
require 'gnome_tour_rb/log'

CONFIG = GnomeTourRb::Config
LOG = GnomeTourRb::Log

$failures = 0

def check(description)
  case yield
  when true then puts "ok   #{description}"
  else
    puts "FAIL #{description}"
    $failures += 1
  end
end

# Runs the block with the environment set, then puts it back.
def with_env(env)
  env.to_h { |key, _| [key, ENV.fetch(key, nil)] }.tap do |saved|
    env.each { |key, value| ENV[key] = value }
    LOG.reset!

    begin
      yield
    ensure
      saved.each { |key, value| ENV[key] = value }
      LOG.reset!
    end
  end
end

# --- Build profile ----------------------------------------------------------

with_env('GNOME_TOUR_RB_PROFILE' => 'default') do
  check('default profile is unnamed') { CONFIG.profile == '' }
  check('default app id has no suffix') { CONFIG.app_id == 'org.gnome.Tour.Rb' }
  check('default version has no suffix') { CONFIG.version == '50.0' }
  check('default build is not a development one') { !CONFIG.development? }
end

with_env('GNOME_TOUR_RB_PROFILE' => 'development') do
  check('development profile is Devel') { CONFIG.profile == 'Devel' }
  check('development app id is suffixed') { CONFIG.app_id == 'org.gnome.Tour.RbDevel' }
  check('development version carries a suffix') { CONFIG.version.start_with?('50.0-') }
  check('a devel icon is shipped for it') do
    File.exist?(File.join(CONFIG.pkgdatadir, 'icons/hicolor/scalable/apps/org.gnome.Tour.RbDevel.svg'))
  end
end

check('the data directory is the one that holds the artwork') do
  File.exist?(File.join(CONFIG.pkgdatadir, 'assets/welcome.svg'))
end

# --- Logging ----------------------------------------------------------------

with_env('GNOME_TOUR_RB_LOG' => nil, 'G_MESSAGES_DEBUG' => nil) do
  check('quiet by default') { LOG.level == Logger::ERROR }
end

with_env('GNOME_TOUR_RB_LOG' => nil, 'G_MESSAGES_DEBUG' => 'gnome_tour_rb') do
  check('G_MESSAGES_DEBUG naming the domain turns on debug') { LOG.level == Logger::DEBUG }
end

with_env('GNOME_TOUR_RB_LOG' => nil, 'G_MESSAGES_DEBUG' => 'all') do
  check('G_MESSAGES_DEBUG=all turns on debug') { LOG.level == Logger::DEBUG }
end

with_env('GNOME_TOUR_RB_LOG' => nil, 'G_MESSAGES_DEBUG' => 'some-other-domain') do
  check('another domain leaves us quiet') { LOG.level == Logger::ERROR }
end

with_env('GNOME_TOUR_RB_LOG' => 'info', 'G_MESSAGES_DEBUG' => nil) do
  check('an explicit level wins') { LOG.level == Logger::INFO }
end

# --- The desktop and metainfo merge ----------------------------------------

require 'tmpdir'

Dir.mktmpdir do |dir|
  system(
    { 'GNOME_TOUR_RB_PROFILE' => 'default' },
    'ruby',
    File.expand_path('../scripts/merge_translations.rb', __dir__),
    dir,
    out: File::NULL,
  )

  desktop = File.read(File.join(dir, 'org.gnome.Tour.Rb.desktop'), encoding: 'UTF-8')
  metainfo = File.read(File.join(dir, 'org.gnome.Tour.Rb.metainfo.xml'), encoding: 'UTF-8')

  check('the desktop entry keeps its untranslated key') { desktop.include?("\nName=Tour\n") }
  check('the desktop entry gains a translated name') { desktop.include?("\nName[de]=Einführung\n") }
  check('the desktop entry translates the generic name') do
    desktop.include?("\nGenericName[de]=Begrüßer und Einführung\n")
  end
  check('the desktop entry translates the keywords') { desktop.match?(/\nKeywords\[de\]=/) }
  check('the desktop entry leaves other keys alone') { desktop.scan(/^Exec/).length == 1 }
  check('the application id is substituted in') { desktop.include?("\nIcon=org.gnome.Tour.Rb\n") }
  check('no template token survives') { !desktop.include?('@APP_ID@') }

  check('the metainfo gains a translated name') do
    metainfo.include?('<name xml:lang="de">Einführung</name>')
  end
  check('the metainfo gains a translated summary') { metainfo.match?(/<summary xml:lang="de">/) }
  check('the metainfo translates the description') { metainfo.match?(%r{<p xml:lang="de">.*</p>}) }
  check('the metainfo translates the developer name') do
    metainfo.include?('<name xml:lang="de">Das GNOME-Projekt</name>')
  end
  check('the metainfo id is substituted in') { metainfo.include?('<id>org.gnome.Tour.Rb</id>') }
  check('untranslated release notes are left alone') do
    metainfo.scan(/<p xml:lang="de">Updated translations\./).empty?
  end
  check('every language in LINGUAS with a catalogue is represented') do
    metainfo.scan(/<summary xml:lang="([^"]+)">/).flatten.length >= 60
  end
end

puts
case $failures
when 0 then puts 'all checks passed'
else
  puts "#{$failures} check(s) failed"
  exit 1
end
