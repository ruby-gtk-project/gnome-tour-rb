# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'i18n'

module GnomeTourRb
  # The carousel, its dot indicator, and the three overlaid navigation
  # buttons. The buttons cross-fade as the carousel scrolls: `start` is the
  # suggested-action button on the welcome page, `next` takes over for the
  # rest of the tour, and `previous` fades in once the tour has started.
  class Paginator
    include I18n

    attr_reader :pages, :current_page

    def initialize
      @pages = []
      @current_page = 0
      @going_backward = false
    end

    def build
      bin.tap do |b|
        b.child = toolbar_view

        toolbar_view.tap do |tv|
          tv.add_top_bar(header_bar)
          tv.content = overlay

          header_bar.title_widget = carousel_dots

          overlay.tap do |o|
            o.child = carousel
            o.add_overlay(previous_button)
            o.add_overlay(next_button)
            o.add_overlay(start_button)
          end

          carousel.signal_connect('notify::position') { on_position_notify }
        end

        b.add_controller(key_controller)

        key_controller.signal_connect('key-pressed') do |_controller, keyval, _code, _state|
          on_key_pressed(keyval)
        end
      end
    end

    def add_page(page)
      carousel.insert(page, pages.length)
      pages.push(page)

      on_position_notify
    end

    # Advance one page, or answer nil when there is no page to advance to —
    # the window turns that nil into a close.
    def try_next
      case current_page + 1
      when carousel.n_pages then nil
      else set_page(current_page + 1)
      end
    end

    def try_previous
      case current_page
      when 0 then nil
      else set_page(current_page - 1)
      end
    end

    def set_page(page_nr)
      remember_direction(page_nr)
      focus_button(page_nr)
      scroll_to(page_nr)

      page_nr
    end

    # Which button keeps the focus depends on which way the tour is being
    # walked: forward from the first page, or back from the last.
    def remember_direction(page_nr)
      case page_nr
      when carousel.n_pages - 1 then @going_backward = true
      when 0 then @going_backward = false
      end
    end

    def focus_button(page_nr)
      case [@going_backward, page_nr]
      in [true, *] then previous_button.grab_focus
      in [false, 0] then start_button.grab_focus
      else next_button.grab_focus
      end
    end

    def scroll_to(page_nr)
      case page_nr < carousel.n_pages
      when true then carousel.scroll_to(pages[page_nr], true)
      end
    end

    def on_key_pressed(keyval)
      case keyval
      when Gdk::Keyval::KEY_Right then try_next
      when Gdk::Keyval::KEY_Left then try_previous
      end

      false
    end

    # Cross-fade the three buttons against the carousel's fractional scroll
    # position, so they track a swipe rather than snapping at page bounds.
    def on_position_notify
      apply_opacities(carousel.position, carousel.n_pages - 2.0)

      @current_page = carousel.position.round
    end

    def apply_opacities(position, forelast_page)
      opacity_previous, opacity_start, opacity_next = opacities(position, forelast_page)

      fade(start_button, opacity_start)
      fade(next_button, opacity_next)
      fade(previous_button, opacity_previous)

      # While the carousel settles onto the last page the next button is still
      # visible, and pressing it there would scroll past the end.
      start_button.can_target = opacity_next < Float::EPSILON
      next_button.can_target = opacity_next.positive? && position <= forelast_page
    end

    def opacities(position, forelast_page)
      case position
      when 0.0...1.0 then [position, 1.0 - position, position]
      when ..forelast_page then [1.0, 0.0, 1.0]
      else [1.0, 0.0, (carousel.n_pages - 1.0) - position]
      end
    end

    def fade(button, opacity)
      button.opacity = opacity
      button.visible = opacity.positive?
    end

    def bin = @bin ||= Adwaita::Bin.new
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Gtk::HeaderBar.new
    def key_controller = @key_controller ||= Gtk::EventControllerKey.new

    def carousel
      @carousel ||= Adwaita::Carousel.new.tap do |c|
        c.hexpand = true
        c.vexpand = true
        c.scroll_params = Adwaita::SpringParams.new(1.0, 0.5, 300.0)
      end
    end

    def carousel_dots
      @carousel_dots ||= Adwaita::CarouselIndicatorDots.new.tap do |dots|
        dots.carousel = carousel
      end
    end

    def overlay
      @overlay ||= Gtk::Overlay.new.tap do |o|
        o.valign = :center
      end
    end

    def previous_button
      @previous_button ||= nav_button('prev-large-symbolic', _('Previous'), 'win.previous-page').tap do |b|
        b.halign = :start
        b.margin_start = 12
      end
    end

    def next_button
      @next_button ||= nav_button('next-large-symbolic', _('Next'), 'win.next-page').tap do |b|
        b.halign = :end
        b.margin_end = 12
      end
    end

    def start_button
      @start_button ||= nav_button('next-large-symbolic', _('Start'), 'win.start-tour').tap do |b|
        b.halign = :end
        b.margin_end = 12
        b.add_css_class('suggested-action')
      end
    end

    private

      def nav_button(icon_name, tooltip, action_name)
        Gtk::Button.new.tap do |b|
          b.icon_name = icon_name
          b.tooltip_text = tooltip
          b.action_name = action_name
          b.valign = :center
          b.add_css_class('circular')
        end
      end
  end
end
