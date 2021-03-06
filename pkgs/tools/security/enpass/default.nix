{stdenv, system, fetchurl, dpkg, openssl, xorg
, glib, mesa, libpulseaudio, zlib, dbus, fontconfig, freetype
, gtk2, pango, atk, cairo, gdk_pixbuf, jasper, xkeyboardconfig
, makeWrapper , makeDesktopItem, python, pythonPackages, lib}:
assert system == "i686-linux" || system == "x86_64-linux";
let
  all_data = (with builtins; fromJSON (readFile ./data.json));
  system_map = {
    i686-linux = "i386";
    x86_64-linux = "amd64";
  };

  data = (with builtins; getAttr (getAttr system system_map) all_data);

  baseUrl = http://repo.sinew.in;
  
  # used of both wrappers and libpath
  libPath = lib.makeLibraryPath (with xorg; [
    openssl
    mesa
    fontconfig
    freetype
    libpulseaudio
    zlib
    dbus
    libX11
    libXi
    libSM
    libICE
    libXext
    libXrender
    libXScrnSaver
    glib
    gtk2
    pango
    cairo
    atk
    gdk_pixbuf
    jasper
    stdenv.cc.cc
  ]);
  package = stdenv.mkDerivation rec {

    inherit (data) version;
    name = "enpass-${version}";

    src = fetchurl {
      inherit (data) sha256;
      url = "${baseUrl}/${data.path}";
    };

    meta = {
      description = "a well known password manager";
      homepage = https://www.enpass.io/;
      maintainer = lib.maintainers.ronny;
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };

    buildInputs = [makeWrapper dpkg];
    phases = [ "unpackPhase" "installPhase" ];

    unpackPhase = "dpkg -X $src .";
    installPhase=''
      mkdir $out
      cp -r opt/Enpass/*  $out
      cp -r usr/* $out
      rm $out/bin/runenpass.sh

      sed \
      	-i s@/opt/Enpass/bin/runenpass.sh@$out/bin/Enpass@ \
      	$out/share/applications/enpass.desktop 

      patchelf  \
        --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
        $out/bin/Enpass

      wrapProgram $out/bin/Enpass \
        --set LD_LIBRARY_PATH "${libPath}:$out/lib:$out/plugins/sqldrivers" \
        --set QT_PLUGIN_PATH "$out/plugins" \
        --set QT_QPA_PLATFORM_PLUGIN_PATH "$out/plugins/platforms" \
        --set QT_XKB_CONFIG_ROOT "${xkeyboardconfig}/share/X11/xkb" \
        --set HIDE_TOOLBAR_LINE 0
    '';
  };
  updater = {
    update = stdenv.mkDerivation rec {
      name = "enpass-update-script";
      SCRIPT =./update_script.py;
      
      buildInputs = with pythonPackages; [python requests pathlib2 six attrs ];
      shellHook = ''
      exec python $SCRIPT --target pkgs/tools/security/enpass/data.json --repo ${baseUrl}
      '';

    };
  };
in (package // {refresh = updater;}) 
