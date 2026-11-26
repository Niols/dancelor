{
  pkgs,
  tuneType,
  makeTuneSnippets,
  withArgumentType,
  setupFontconfigCache,
  setupLuaotfloadCache,
  myTexlive,
  myFontconfigFile,
}:

let
  inherit (pkgs)
    lib
    writeText
    ;

  inherit (builtins)
    elemAt
    replaceStrings
    toJSON
    ;

  inherit (lib)
    concatMapStringsSep
    mkOption
    types
    optionalString
    ;

  inherit (pkgs)
    runCommand
    ;

  forConcat = xs: f: concatMapStringsSep "\n" f xs;
  escapeLatexString = replaceStrings [ "&" "#" ] [ "\\&" "\\#" ];

  partType = types.submodule {
    options = {
      name = mkOption {
        description = "The name of the part.";
        type = types.str;
      };
    };
  };

  setType = types.submodule {
    options = {
      slug = mkOption {
        description = "A slug for the set; it is used to make logs clearer.";
        type = types.str;
      };
      name = mkOption {
        description = "The name of the set.";
        type = types.str;
      };
      conceptor = mkOption {
        description = "The “conceptor” line for the set.";
        type = types.str;
      };
      kind = mkOption {
        description = "The “kind” line for the set.";
        type = types.str;
      };
      contents = mkOption {
        description = "The contents of the set.";
        type = types.listOf tuneType;
      };
    };
  };

  bookType = types.submodule {
    options = {
      slug = mkOption {
        description = "A slug for the book; it is used to make logs clearer.";
        type = types.str;
      };
      name = mkOption {
        description = "The name of the book.";
        type = types.str;
      };
      editor = mkOption {
        description = "The editor of the book.";
        type = types.str;
      };
      contents = mkOption {
        description = "The contents of the book.";
        type = types.listOf (
          ## NOTE: This is a technique for the sum of submodule types. It is
          ## very complicated to do cleanly in practice, so we settle for
          ## something that allows a few more values than expected.
          types.submodule {
            options = {
              part = mkOption {
                type = types.nullOr partType;
                default = null;
              };
              set = mkOption {
                type = types.nullOr setType;
                default = null;
              };
            };
          }
        );
      };
      simple = mkOption {
        description = ''
          Whether the book should be simple, that is with no title page, no
          table of contents, and not two-sided.
        '';
        type = types.bool;
      };
    };
  };

  pdfMetadataType = types.submodule {
    options = {
      title = mkOption { type = types.str; };
      authors = mkOption { type = types.listOf types.str; };
      subjects = mkOption { type = types.listOf types.str; };
    };
  };

  bookPdfArgType = types.submodule {
    options = {
      book = mkOption { type = bookType; };
      specificity = mkOption {
        description = "Specificity of this particular book, eg. Bb instruments or bass clef.";
        type = types.str;
      };
      show_set_titles = mkOption {
        description = "Whether the book should contain set titles.";
        type = types.bool;
      };
      show_running_headers = mkOption {
        description = "Whether the book should contain running headers and footers.";
        type = types.bool;
      };
      pdf_metadata = mkOption {
        description = "PDF metadata";
        type = pdfMetadataType;
      };
    };
  };

  makeBookTexGen =
    type:
    {
      book,
      specificity,
      show_set_titles,
      show_running_headers,
      pdf_metadata,
    }:
    writeText "${type}-${book.slug}.tex" ''
      \newif\ifsimple
      \simple${if book.simple then "true" else "false"}
      \newif\ifShowSetTitles
      \ShowSetTitles${if show_set_titles then "true" else "false"}
      \newif\ifShowRunningHeaders
      \ShowRunningHeaders${if show_running_headers then "true" else "false"}
      \input{preamble}
      \usepackage[
        pdftitle={${escapeLatexString pdf_metadata.title}},
        pdfauthor={${concatMapStringsSep "; " escapeLatexString pdf_metadata.authors}},
        pdfsubject={${concatMapStringsSep "; " escapeLatexString pdf_metadata.subjects}},
        pdfcreator={Dancelor},
      ]{hyperref}
      \title{${escapeLatexString book.name}}
      \author{${escapeLatexString book.editor}}
      \specificity{${escapeLatexString specificity}}
      \begin{document}
      ${optionalString (!book.simple) "\\maketitle\n"}
      ${forConcat book.contents (
        page:
        if page.part != null then
          ''
            \part{${escapeLatexString page.part.name}}
          ''
        else if page.set != null then
          ''
            \begin{set}{${escapeLatexString page.set.name}}{${escapeLatexString page.set.conceptor}}{${escapeLatexString page.set.kind}}
              ${forConcat page.set.contents (tune: ''
                \tune{${escapeLatexString tune.name}}{${escapeLatexString tune.instructions}}{${escapeLatexString tune.composer}}{${makeTuneSnippets tune}/snippet.pdf}
              '')}
            \end{set}
          ''
        else
          throw "Unexpected page type: ${toJSON page}"
      )}
      ${optionalString (!book.simple) "\\tableofcontents\n"}
      \end{document}
    '';

  makeBookPdfGen =
    type:
    withArgumentType "makeBookPdf" bookPdfArgType (
      book@{ ... }:
      runCommand "${type}-${book.book.slug}"
        {
          preferLocalBuild = true;
          allowSubstitutes = false;
          buildInputs = [ myTexlive ];
          FONTCONFIG_FILE = myFontconfigFile;
        }
        ''
          ${setupFontconfigCache}
          ${setupLuaotfloadCache}
          cp ${./book}/*.tex ${./book}/*.lua .
          cp ${makeBookTexGen type book} ${type}.tex
          export max_print_line=1000000000 # prevent TeX from hard wrapping its output
          texfot ${if book.book.simple then "lualatex" else "latexmk -pdflua"} ${type}
          mkdir $out
          mv ${type}.pdf $out
        ''
    );

  makeBookPdf = makeBookPdfGen "book";

  setPdfArgType = types.submodule {
    options = {
      set = mkOption { type = setType; };
      specificity = mkOption {
        description = "Specificity of this particular set, eg. Bb instruments or bass clef.";
        type = types.str;
      };
      show_set_titles = mkOption {
        description = "Whether the set should contain a title.";
        type = types.bool;
      };
      show_running_headers = mkOption {
        description = "Whether the set should contain running headers and footers.";
        type = types.bool;
      };
      pdf_metadata = mkOption {
        description = "PDF metadata";
        type = pdfMetadataType;
      };
    };
  };

  makeSetPdf = withArgumentType "makeSetPdf" setPdfArgType (
    set@{ ... }:
    makeBookPdfGen "set" {
      book = {
        inherit (set.set) slug;
        name = "";
        contents = [ { set = set.set; } ];
        editor = "";
        simple = true;
      };
      inherit (set)
        specificity
        show_set_titles
        show_running_headers
        pdf_metadata
        ;
    }
  );

  setsZipArgType = types.submodule {
    options = {
      ## FIXME: guarantee non-emtpy list?
      sets = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              set = mkOption { type = setType; };
              pdf_metadata = mkOption { type = pdfMetadataType; };
            };
          }
        );
      };
      specificity = mkOption {
        description = "Specificity of these particular sets, eg. Bb instruments or bass clef.";
        type = types.str;
      };
      show_set_titles = mkOption {
        description = "Whether the sets should contain titles.";
        type = types.bool;
      };
      show_running_headers = mkOption {
        description = "Whether the sets should contain running headers and footers.";
        type = types.bool;
      };
    };
  };

  makeSetsZip = withArgumentType "makeSetsZip" setsZipArgType (
    sets@{ ... }:
    runCommand "sets-${(elemAt sets.sets 0).set.slug}"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        buildInputs = [ pkgs.zip ];
      }
      ''
        ${forConcat sets.sets (
          { set, pdf_metadata }:
          let
            pdf = makeSetPdf {
              inherit set pdf_metadata;
              inherit (sets) specificity show_set_titles show_running_headers;
            };
          in
          ''
            offset=1
            target () {
              if [ "$offset" -eq 1 ]; then echo "${set.slug}.pdf"; else echo "${set.slug}-$offset.pdf"; fi
            }
            while [ -e "$(target)" ]; do offset=$((offset + 1)); done
            cp ${pdf}/set.pdf "$(target)"
            zip sets.zip "$(target)"
          ''
        )}
        mkdir $out && mv sets.zip $out
      ''
  );

in
{
  inherit
    makeBookPdf
    makeSetPdf
    makeSetsZip
    ;
}
