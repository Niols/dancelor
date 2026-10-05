{ pkgs, ... }:

let
  withArgumentType =
    name: type: cont: args:
    if !(type.check args) then
      throw "The value passed to `${name}` does not have the expected type."
    else
      let
        merged =
          type.merge
            [ ]
            [
              {
                value = args;
                file = "argument passed to ${name}";
              }
            ];
      in
      cont merged;

  ## Setup script to configure fontconfig and luaotfload with a writable cache directories.
  ## This prevents "No writable cache directories" warnings from fontconfig and avoids
  setupFontconfigCache = ''
    export HOME=$(mktemp -d)
    mkdir -p "$HOME"/.cache/fontconfig
    cat <<EOF >$HOME/fonts.conf
    <?xml version="1.0"?>
    <fontconfig>
      <include>$FONTCONFIG_FILE</include>
      <cachedir>$HOME/.cache/fontconfig</cachedir>
    </fontconfig>
    EOF
    export FONTCONFIG_FILE=$HOME/fonts.conf
  '';

  ## LuaLaTeX with only the packages that we need. `texliveBasic` brings
  ## `latex-bin`, which provides the `lualatex` format. NOTE: the font comes
  ## from the TeX package `sourcesanspro`, not from `myFontconfigFile`.
  myTexlive = pkgs.texliveBasic.withPackages (
    ps: with ps; [
      etoolbox
      extsizes
      fancyhdr
      fontspec
      geometry
      graphics
      hyperref
      latexmk
      luaotfload
      sourcesanspro
      texfot
    ]
  );

  ## A `fonts.conf` file ready to be passed as the `FONTCONFIG_FILE` environment
  ## variable that provides Source Sans Pro _and nothing else_. NOTE: avoid
  ## `pkgs.makeFontsConf` which also brings in a lot of other fonts.
  myFontconfigFile =
    with pkgs;
    writeText "fonts.conf" ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <dir>${source-sans-pro}</dir>
      </fontconfig>
    '';

  ## The luaotfload cache is computed when starting LuaLaTeX if not
  ## precomputed, and that takes a few seconds. We save them by
  ## storing it in the Nix store permanently and pointing subsequent
  ## runs of LuaLaTeX to it.
  ##
  luaotfloadCache =
    pkgs.runCommand "luaotfload-cache"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        buildInputs = [ myTexlive ];
        FONTCONFIG_FILE = myFontconfigFile;
      }
      ''
        ${setupFontconfigCache}
        mkdir -p $out
        TEXMFCACHE=$out luaotfload-tool --update --force
      '';

  setupLuaotfloadCache = ''
    mkdir -p texmf-cache
    cp -r ${luaotfloadCache}/* texmf-cache/
    chmod -R u+w texmf-cache/
    export TEXMFVAR=$PWD/texmf-cache
  '';

in
{
  inherit
    withArgumentType
    setupFontconfigCache
    setupLuaotfloadCache
    myTexlive
    myFontconfigFile
    ;
}
