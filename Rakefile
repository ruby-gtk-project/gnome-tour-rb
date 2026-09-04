# frozen_string_literal: true

desc 'Run the checks: the catalogue and os-release readers, then the UI'
task :test do
  %w[test/catalogue_test.rb test/drive_tour.rb].each do |script|
    puts "\n== #{script}"
    # No display needed — GTK4 renders the window to an offscreen surface, and
    # the screenshots in tmp/shots come out the same as a real session's.
    sh({ 'DISPLAY' => nil, 'WAYLAND_DISPLAY' => nil }, 'ruby', script)
  end
end

desc 'Run the application'
task :run do
  sh 'bin/gnome-tour-rb'
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[test lint]
