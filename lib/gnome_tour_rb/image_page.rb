# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'paths'

module GnomeTourRb
  # One page of the tour: an illustration above a heading and a body line.
  #
  # Upstream is a GtkWidget subclass with an AdwClampLayout layout manager;
  # an AdwClamp is the same constraint in one widget, and it carries the
  # `page` style class the stylesheet selects on by position.
  class ImagePage
    attr_reader :asset, :head, :body

    def initialize(asset:, head:, body: '')
      @asset = asset
      @head = head
      @body = body
    end

    def build
      clamp.tap do |c|
        c.child = container

        container.tap do |box|
          box.append(picture)
          box.append(head_label)
          box.append(body_label)
        end
      end
    end

    # The body of the welcome page is only known at runtime, so it is set
    # after construction.
    def body=(text)
      @body = text
      body_label.label = text
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |c|
        c.add_css_class('page')
        c.hexpand = true
        c.vexpand = true
        c.halign = :fill
        c.valign = :fill
      end
    end

    def container
      @container ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.valign = :center
        box.halign = :center
        box.vexpand = true
        box.margin_top = 12
        box.margin_bottom = 48
        box.margin_start = 12
        box.margin_end = 12
      end
    end

    def picture
      @picture ||= Gtk::Picture.new.tap do |p|
        p.filename = Paths.asset(asset)
        p.can_shrink = true
        p.content_fit = :contain
      end
    end

    def head_label
      @head_label ||= Gtk::Label.new(head).tap do |l|
        l.add_css_class('title-1')
        l.valign = :center
        l.justify = :center
        l.margin_top = 36
      end
    end

    def body_label
      @body_label ||= Gtk::Label.new(body).tap do |l|
        l.add_css_class('body')
        l.lines = 2
        l.wrap = true
        l.valign = :center
        l.justify = :center
        l.margin_top = 12
      end
    end
  end
end
