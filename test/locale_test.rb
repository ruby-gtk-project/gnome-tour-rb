# frozen_string_literal: true

# The catalogue reaches the widgets. `test/catalogue_test.rb` proves the PO
# files parse; this proves the strings arrive in the window, which is a
# separate question — the catalogue is read once at startup, so it needs its
# own process with the locale already set.
#
#   LANGUAGE=de ruby test/locale_test.rb

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['LANGUAGE'] = 'de'
ENV['LC_ALL'] = 'de_DE.UTF-8'

require 'gnome_tour_rb'
require_relative 'gtk_driver'

app = GnomeTourRb::Application.new

GtkDriver.drive(app, shots: 'tmp/shots', interval: 200, timeout: 120) do |d, _app|
  window = -> { app.main_window }
  paginator = -> { app.main_window.paginator }

  d.window { window.call.window }

  d.step('the catalogue was picked up') do
    d.check('German is selected') { GnomeTourRb::I18n.language == 'de' }
  end

  d.step('every page heading is translated') do
    d.check('the welcome heading') { window.call.welcome_page.head_label.label == "Los geht's" }
    d.check('the overview heading') do
      window.call.image_pages[1].head_label.label == 'Einen Überblick erhalten'
    end
    d.check('the closing heading') { window.call.image_pages[6].head_label.label == "Das war's!" }
  end

  d.step('bodies and tooltips are translated') do
    d.check('a page body') do
      window.call.image_pages[6].body_label.label ==
        'Weitere Erklärungen und Tipps finden Sie in der Hilfe-Anwendung.'
    end
    d.check('the start tooltip') { paginator.call.start_button.tooltip_text == 'Starten' }
    d.check('the next tooltip') { paginator.call.next_button.tooltip_text == 'Weiter' }
    d.check('the previous tooltip') { paginator.call.previous_button.tooltip_text == 'Zurück' }
  end

  d.step('the welcome body is translated and still names the OS') do
    window.call.welcome_page.body_label.label.tap do |body|
      d.check('translated') { body.start_with?('Lernen Sie') }
      d.check('names the OS') { body.include?(GnomeTourRb::OsInfo.name) }
      d.check('no placeholder survives') { !body.include?('{name}') && !body.include?('{version}') }
    end

    d.shot('06-german')
  end
end
