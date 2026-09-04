# frozen_string_literal: true

desc 'Run the checks: the catalogue, config and os-release readers, then the UI'
task :test do
  %w[test/catalogue_test.rb test/config_test.rb test/cli_test.rb test/quit_test.rb
     test/drive_tour.rb
].each do |script|
    puts "\n== #{script}"
    # No display needed — GTK4 renders the window to an offscreen surface, and
    # the screenshots in tmp/shots come out the same as a real session's.
    sh({ 'DISPLAY' => nil, 'WAYLAND_DISPLAY' => nil }, 'ruby', script)
  end
end

desc 'Merge po/*.po into the desktop entry and the metainfo (meson i18n.merge_file)'
task :desktop do
  sh 'ruby', 'scripts/merge_translations.rb'
end

desc 'Validate the generated desktop entry and metainfo'
task validate: :desktop do
  app_id = `ruby -Ilib -rgnome_tour_rb/config -e 'print GnomeTourRb::Config.app_id'`

  sh 'desktop-file-validate', "data/#{app_id}.desktop"
  sh 'appstreamcli', 'validate', '--no-net', '--explain', "data/#{app_id}.metainfo.xml"
end

desc 'Install the pre-commit hook (meson does this for a development build)'
task :hooks do
  sh 'cp', '-f', 'hooks/pre-commit.hook', '.git/hooks/pre-commit'
end

desc 'Run the application'
task :run do
  sh 'bin/gnome-tour-rb'
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[test validate lint]
