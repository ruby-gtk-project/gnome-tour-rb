# frozen_string_literal: true

# Stands in for meson's `i18n.merge_file`: substitutes the application id into
# the desktop and metainfo templates and folds every shipped translation back
# into them, so the app's name, generic name, keywords, summary and description
# are localised in the shell and in the software centre.
#
#   ruby scripts/merge_translations.rb [output-directory]

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'gnome_tour_rb/config'
require 'gnome_tour_rb/i18n'

module MergeTranslations
  # The keys GNU `msgfmt --desktop` localises, minus the ones this file has no
  # use for.
  DESKTOP_KEYS = %w[Name GenericName Comment Keywords].freeze

  # The appstream elements `msgfmt --xml` localises, per the shared ITS rules.
  # `caption` and `developer > name` are covered by the same element names.
  XML_ELEMENTS = %w[name summary p li caption].freeze

  module_function

  def catalogues
    @catalogues ||= languages.to_h { |lang| [lang, GnomeTourRb::I18n.parse_po(po_path(lang))] }
                             .reject { |_lang, catalogue| catalogue.empty? }
  end

  def languages
    File.readlines(File.join(GnomeTourRb::Paths.po_dir, 'LINGUAS'), encoding: 'UTF-8')
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?('#') }
        .select { |lang| File.exist?(po_path(lang)) }
  end

  def po_path(lang) = File.join(GnomeTourRb::Paths.po_dir, "#{lang}.po")

  def substitute(template) = template.gsub('@APP_ID@', GnomeTourRb::Config.app_id)

  # --- Desktop entry --------------------------------------------------------

  # Each translatable key gains one `Key[lang]=value` line per language, in the
  # order the LINGUAS file lists them.
  def desktop(template)
    substitute(template).lines.flat_map { |line| desktop_lines(line) }.join
  end

  def desktop_lines(line)
    line.match(/\A([A-Za-z-]+)=(.*)\n?\z/).then do |match|
      case match && DESKTOP_KEYS.include?(match[1])
      when true then [line, *translated_desktop_lines(match[1], match[2])]
      else [line]
      end
    end
  end

  def translated_desktop_lines(key, value)
    catalogues.filter_map do |lang, catalogue|
      catalogue[value].then do |translation|
        case translation
        when nil then nil
        else "#{key}[#{lang}]=#{translation}\n"
        end
      end
    end
  end

  # --- Metainfo -------------------------------------------------------------

  # Each translatable element gains one `xml:lang`-qualified sibling per
  # language, indented to match, the way `msgfmt --xml` emits them.
  def metainfo(template)
    substitute(template).lines.flat_map { |line| metainfo_lines(line) }.join
  end

  def metainfo_lines(line)
    line.match(%r{\A(\s*)<(#{XML_ELEMENTS.join('|')})>(.+)</\2>\n?\z}o).then do |match|
      case match.nil?
      when true then [line]
      else [line, *translated_metainfo_lines(match[1], match[2], match[3])]
      end
    end
  end

  def translated_metainfo_lines(indent, element, text)
    catalogues.filter_map do |lang, catalogue|
      catalogue[unescape_xml(text)].then do |translation|
        case translation
        when nil then nil
        else %(#{indent}<#{element} xml:lang="#{lang}">#{escape_xml(translation)}</#{element}>\n)
        end
      end
    end
  end

  def escape_xml(text) = text.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')

  def unescape_xml(text) = text.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&amp;', '&')

  # --- Entry point ----------------------------------------------------------

  def run(output_dir)
    app_id = GnomeTourRb::Config.app_id

    {
      "#{app_id}.desktop"      => [desktop_template, method(:desktop)],
      "#{app_id}.metainfo.xml" => [metainfo_template, method(:metainfo)],
    }.each do |name, (template, merge)|
      File.join(output_dir, name).tap do |path|
        File.write(path, merge.call(File.read(template, encoding: 'UTF-8')), encoding: 'UTF-8')
        puts "wrote #{path} (#{catalogues.length} languages)"
      end
    end
  end

  def data_dir = GnomeTourRb::Paths.data_dir

  def desktop_template = File.join(data_dir, 'org.gnome.Tour.Rb.desktop.in')

  def metainfo_template = File.join(data_dir, 'org.gnome.Tour.Rb.metainfo.xml.in')
end

MergeTranslations.run(ARGV.fetch(0, MergeTranslations.data_dir))
