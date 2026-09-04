{
  description = "gnome-tour-rb — a Ruby GTK4 port of GNOME Tour";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ruby = pkgs.ruby_3_3;

        # Shared libraries every ruby-gnome extension links against, plus the
        # ones console-rb needs at runtime (libadwaita, VTE).
        gtkStack = with pkgs; [
          glib
          gobject-introspection
          cairo
          pango
          gdk-pixbuf
          graphene
          atk
          gtk4
          libadwaita
          harfbuzz
          # The tour's swipe pages animate two SVGs as CSS backgrounds, and
          # GTK loads CSS images through gdk-pixbuf — without librsvg's loader
          # those rules parse cleanly and then paint nothing.
          librsvg
        ]
        # The Ruby `pkg-config` gem resolves `Requires.private` transitively and
        # hard-fails if any .pc in the chain is missing, so gtk4's whole
        # private closure has to be on PKG_CONFIG_PATH, not just its public deps.
        ++ (with pkgs; [
          fontconfig
          freetype
          libepoxy
          libpng
          libxkbcommon
          pcre2
          util-linux
          wayland
          zlib
          fribidi
          libdatrie
          libthai
          libselinux
          libsepol
          expat
          brotli
          bzip2
          graphite2
          icu
          libffi
          libxml2
          lerc
          libdeflate
          xz
          zstd
        ])
        ++ (with pkgs; [
          libx11
          libxau
          libxcursor
          libxdmcp
          libxext
          libxfixes
          libxi
          libxinerama
          libxrandr
          libxrender
          libxcb
          xorgproto
        ]);

        # ruby-gnome gems build C extensions with extconf.rb + the pkg-config
        # gem; nixpkgs only ships gemConfig entries for the GTK3-era subset, so
        # the GTK4 gems get their build inputs declared here.
        rubyGnomeGem = attrs: {
          nativeBuildInputs = [ pkgs.pkg-config ];
          buildInputs = gtkStack;
        };

        gemConfig = pkgs.defaultGemConfig // {
          gdk4 = rubyGnomeGem;
          gsk4 = rubyGnomeGem;
          gtk4 = rubyGnomeGem;
          graphene1 = rubyGnomeGem;
          adwaita = rubyGnomeGem;
        };

        # `makeSearchPath` would take each package's *first* output, and glib's
        # first output is `bin`, which carries no typelibs — hence the explicit
        # `.out`. at-spi2-core is here for the Atk typelib.
        typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0"
          (map (drv: drv.out or drv) (gtkStack ++ [ pkgs.at-spi2-core ]));

        gems = pkgs.bundlerEnv {
          name = "gnome-tour-rb-gems";
          inherit ruby gemConfig;
          gemdir = ./.;
        };

        # Upstream's meson `profile` option: the development build gets its own
        # application id and icon, and the window wears the `devel` header.
        mkTour = { profile ? "default" }:
          let
            appId =
              if profile == "development" then "org.gnome.Tour.RbDevel"
              else "org.gnome.Tour.Rb";
          in
          pkgs.stdenv.mkDerivation {
          pname = if profile == "development" then "gnome-tour-rb-devel" else "gnome-tour-rb";
          version = "50.0";
          src = ./.;


          GNOME_TOUR_RB_PROFILE = profile;

          nativeBuildInputs = [
            pkgs.makeWrapper
            pkgs.desktop-file-utils   # desktop-file-validate
            pkgs.appstream            # appstreamcli validate
          ];
          buildInputs = [ gems ] ++ gtkStack;

          # Stands in for meson's i18n.merge_file: folds po/*.po back into the
          # desktop entry and the metainfo, and stamps in the application id.
          buildPhase = ''
            runHook preBuild
            ${gems.wrappedRuby}/bin/ruby scripts/merge_translations.rb data
            runHook postBuild
          '';

          doCheck = true;
          checkPhase = ''
            runHook preCheck
            desktop-file-validate data/${appId}.desktop
            appstreamcli validate --no-net --explain data/${appId}.metainfo.xml
            runHook postCheck
          '';

          installPhase = ''
            runHook preInstall

            mkdir -p $out/share/gnome-tour-rb $out/share/applications \
              $out/share/dbus-1/services
            cp -r lib data po $out/share/gnome-tour-rb/
            # bin/ has to sit next to lib/ for the launcher's require_relative.
            install -Dm755 bin/gnome-tour-rb $out/share/gnome-tour-rb/bin/gnome-tour-rb

            cp data/${appId}.desktop $out/share/applications/
            sed "s|@BINDIR@|$out/bin|; s|@APP_ID@|${appId}|" data/org.gnome.Tour.Rb.service \
              > $out/share/dbus-1/services/${appId}.service
            install -Dm644 data/${appId}.metainfo.xml -t $out/share/metainfo

            # The icon is named for the profile; the symbolic one is renamed to
            # match, the way meson installs it.
            install -Dm644 data/icons/hicolor/scalable/apps/${appId}.svg \
              -t $out/share/icons/hicolor/scalable/apps
            install -Dm644 data/icons/hicolor/scalable/apps/org.gnome.Tour.Rb-symbolic.svg \
              $out/share/icons/hicolor/symbolic/apps/${appId}-symbolic.svg

            # -rbundler/setup puts the bundled gems on the load path, and
            # GI_TYPELIB_PATH keeps GObject-Introspection from re-registering
            # types the cairo gem's C extension has already registered.
            makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/gnome-tour-rb \
              --add-flags "-rbundler/setup" \
              --set GNOME_TOUR_RB_PROFILE "${profile}" \
              --add-flags "$out/share/gnome-tour-rb/bin/gnome-tour-rb" \
              --set GI_TYPELIB_PATH "${typelibPath}" \
              --set GDK_PIXBUF_MODULE_FILE "${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" \
              --prefix XDG_DATA_DIRS : "$out/share" \
              --prefix XDG_DATA_DIRS : "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}" \
              --prefix XDG_DATA_DIRS : "${pkgs.adwaita-icon-theme}/share"

            runHook postInstall
          '';
        };

      in
      {
        packages.default = mkTour { };
        packages.devel = mkTour { profile = "development"; };

        apps.default = flake-utils.lib.mkApp { drv = self.packages.${system}.default; };

        devShells.default = pkgs.mkShell {
          name = "gnome-tour-rb-devshell";

          packages = [
            gems
            gems.wrappedRuby
            pkgs.bundler
            pkgs.bundix
            pkgs.pkg-config
            pkgs.adwaita-icon-theme
            pkgs.gsettings-desktop-schemas
            pkgs.desktop-file-utils   # rake validate
            pkgs.appstream            # rake validate
          ] ++ gtkStack;

          # Icons, GSettings schemas and the GTK portal all resolve through
          # XDG_DATA_DIRS; without these the window opens with blank icons.
          shellHook = ''
            export GDK_PIXBUF_MODULE_FILE="${pkgs.librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
            export XDG_DATA_DIRS="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}:${pkgs.adwaita-icon-theme}/share:$XDG_DATA_DIRS"
            unset BUNDLE_GEMFILE BUNDLE_FROZEN BUNDLE_PATH
            echo "gnome-tour-rb devshell — ruby $(ruby -e 'print RUBY_VERSION')"
            echo "  ./bin/gnome-tour-rb   run the app"
            echo "  rake                  test + lint"
          '';
        };
      });
}
