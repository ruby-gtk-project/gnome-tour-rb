# frozen_string_literal: true

require_relative 'paths'

module GnomeTourRb
  # Upstream links against gettext. There is no gettext binding in the Ruby
  # GTK stack, so this reads the same `po/*.po` files directly — the catalogue
  # is ten strings, which is far cheaper than a msgfmt build step plus a
  # runtime MO reader.
  module I18n
    module_function

    # Translate, falling back to the untranslated string. Named `_` so call
    # sites read the way gettext's do.
    def _(text)
      catalogue.fetch(text, text)
    end

    def catalogue
      @catalogue ||= load_catalogue
    end

    # Reset between tests, or after changing the environment.
    def reset!
      @catalogue = nil
      @language = nil
    end

    # The first locale from the environment that we actually ship a catalogue
    # for. `C` and `POSIX` mean "no translation", so they resolve to nothing.
    def language
      @language ||= candidates.find { |lang| File.exist?(po_path(lang)) }
    end

    def candidates
      locales.flat_map { |locale| [locale, locale.split('_').first] }
             .reject { |lang| %w[C POSIX].include?(lang) }
             .uniq
    end

    def locales
      %w[LANGUAGE LC_ALL LC_MESSAGES LANG]
        .filter_map { |var| ENV.fetch(var, nil) }
        .reject(&:empty?)
        .flat_map { |value| value.split(':') }
        .map { |value| value.split(/[.@]/).first }
    end

    def po_path(lang) = File.join(Paths.po_dir, "#{lang}.po")

    def load_catalogue
      case language
      when nil then {}
      else parse_po(po_path(language))
      end
    end

    # A deliberately small PO parser: msgid/msgstr pairs with continuation
    # lines. Plurals and contexts are not used by this catalogue, and fuzzy
    # entries are dropped the way gettext drops them.
    def parse_po(path)
      {}.tap do |catalogue|
        entry = new_entry

        # Explicitly UTF-8: PO files are, but Ruby would otherwise decode them
        # with the locale's encoding, which is US-ASCII under a bare `LANG=C`.
        File.foreach(path, encoding: 'UTF-8') do |line|
          entry = consume(catalogue, entry, line.chomp)
        end

        store(catalogue, entry)
      end
    end

    def new_entry = { msgid: +'', msgstr: +'', field: nil, fuzzy: false }

    def consume(catalogue, entry, line)
      case line
      when /\A#,.*\bfuzzy\b/
        boundary(catalogue, entry).merge(fuzzy: true)
      when /\A#/
        boundary(catalogue, entry)
      when /\A\s*\z/
        store(catalogue, entry)
        new_entry
      when /\Amsgid\s+"(.*)"\z/
        boundary(catalogue, entry).merge(field: :msgid, msgid: unescape(Regexp.last_match(1)))
      when /\Amsgstr\s+"(.*)"\z/
        entry.merge(field: :msgstr, msgstr: unescape(Regexp.last_match(1)))
      when /\A"(.*)"\z/
        append(entry, Regexp.last_match(1))
      else
        entry
      end
    end

    # A completed msgid/msgstr pair ends as soon as a line appears that is not
    # one of its own continuations: PO files are not required to separate
    # entries with a blank line, and a `#, fuzzy` marker belongs to the entry
    # below it, not the one above.
    def boundary(catalogue, entry)
      case entry[:field]
      when :msgstr
        store(catalogue, entry)
        new_entry
      else
        entry
      end
    end

    def append(entry, text)
      case entry[:field]
      when nil then entry
      else entry.merge(entry[:field] => entry[entry[:field]] + unescape(text))
      end
    end

    def store(catalogue, entry)
      usable = !entry[:fuzzy] && !entry[:msgid].empty? && !entry[:msgstr].empty?

      case usable
      when true then catalogue[entry[:msgid]] = entry[:msgstr]
      end
    end

    def unescape(text)
      text.gsub(/\\(.)/) do
        case Regexp.last_match(1)
        when 'n' then "\n"
        when 't' then "\t"
        else Regexp.last_match(1)
        end
      end
    end
  end
end
