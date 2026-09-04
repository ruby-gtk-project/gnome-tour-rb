# frozen_string_literal: true

# Plain checks on the parts that need no display: the PO reader and the
# os-release reader.
#
#   ruby test/catalogue_test.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'tmpdir'

require 'gnome_tour_rb/i18n'
require 'gnome_tour_rb/os_info'

I18N = GnomeTourRb::I18n

def check(description)
  case yield
  when true then puts "ok   #{description}"
  else
    puts "FAIL #{description}"
    $failures += 1
  end
end

$failures = 0

# --- The shipped catalogues -------------------------------------------------

ENV['LANGUAGE'] = 'de'
I18N.reset!

check('picks German') { I18N.language == 'de' }
check('translates a heading') { I18N._("Let's Begin") == "Los geht's" }
check('translates a two-line body') do
  I18N._('To get more advice and tips, see the Help app.') ==
    'Weitere Erklärungen und Tipps finden Sie in der Hilfe-Anwendung.'
end
check('keeps the placeholders in the welcome body') do
  I18N._('Learn about the key features in {name} {version}.').match?(/\{name\}.*\{version\}/)
end

ENV['LANGUAGE'] = 'pt_BR'
I18N.reset!
check('picks a region-qualified catalogue') { I18N.language == 'pt_BR' }

ENV['LANGUAGE'] = 'de_AT'
I18N.reset!
check('falls back from de_AT to de') { I18N.language == 'de' }

ENV['LANGUAGE'] = 'zz'
ENV['LC_ALL'] = 'zz'
ENV['LC_MESSAGES'] = 'zz'
ENV['LANG'] = 'zz'
I18N.reset!
check('an unknown locale leaves the strings untouched') { I18N._("Let's Begin") == "Let's Begin" }

# --- The parser itself ------------------------------------------------------

Dir.mktmpdir do |dir|
  File.write(File.join(dir, 'xx.po'), <<~PO)
    # a comment
    msgid ""
    msgstr "Content-Type: text/plain; charset=UTF-8\\n"

    msgid "plain"
    msgstr "einfach"

    msgid "wrapped "
    "over lines"
    msgstr "umgebrochen "
    "über Zeilen"
    #, fuzzy
    msgid "unsure"
    msgstr "unsicher"

    msgid "escaped\\nnewline"
    msgstr "maskierter\\nUmbruch"

    msgid "untranslated"
    msgstr ""
  PO

  catalogue = I18N.parse_po(File.join(dir, 'xx.po'))

  check('reads a simple entry') { catalogue['plain'] == 'einfach' }
  check('joins continuation lines') { catalogue['wrapped over lines'] == 'umgebrochen über Zeilen' }
  check('drops fuzzy entries') { !catalogue.key?('unsure') }
  check('unescapes newlines') { catalogue["escaped\nnewline"] == "maskierter\nUmbruch" }
  check('drops untranslated entries') { !catalogue.key?('untranslated') }
  check('drops the header entry') { !catalogue.key?('') }
end

# --- os-release -------------------------------------------------------------

check('names an OS') { !GnomeTourRb::OsInfo.name.empty? }
check('unquotes a quoted value') { GnomeTourRb::OsInfo.unquote('"26.05 (Yarara)"') == '26.05 (Yarara)' }
check('leaves a bare value alone') { GnomeTourRb::OsInfo.unquote('NixOS') == 'NixOS' }
check('falls back to GNOME with no os-release') do
  GnomeTourRb::OsInfo.parse(nil).fetch('NAME', 'GNOME') == 'GNOME'
end

puts
case $failures
when 0 then puts 'all checks passed'
else
  puts "#{$failures} check(s) failed"
  exit 1
end
