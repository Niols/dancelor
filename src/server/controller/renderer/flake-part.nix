{ inputs, ... }:

let
  testTune = {
    slug = "test-slug";
    name = "Test Name";
    composer = "Test Composer";
    content = ''
      \version "2.18.2"
      <<
        \new Voice {
          \key f \minor
          \time 3/4
          \repeat volta 2 {
            f'2. g' aes' bes'
          }
        }
        \new ChordNames {
          \chordmode {
            f2. g:m7 aes bes:dim
          }
        }
      >>
    '';
    first_bar = 1;
    tempo_unit = "4";
    tempo_value = 108;
    chords_kind = "reel";
    show_bar_numbers = true;
    show_time_signatures = true;
  };

  testSetPdfArg = {
    set = {
      slug = "test-slug";
      name = "Test Name";
      conceptor = "Test Conceptor";
      kind = "Test Kind";
      contents = [ ];
    };
    specificity = "none";
    show_set_titles = true;
    show_running_headers = true;
    pdf_metadata = {
      title = "Test PDF Title";
      authors = [
        "Test PDF Author 1"
        "Test PDF Author 2"
      ];
      subjects = [
        "Test PDF Subject 1"
        "Test PDF Subject 2"
      ];
    };
  };

  testBookPdfArg = {
    book = {
      slug = "test-slug";
      name = "Test Name";
      editor = "Test Editor";
      contents = [ ];
      simple = false;
    };
    specificity = "none";
    show_set_titles = true;
    show_running_headers = true;
    pdf_metadata = {
      title = "Test PDF Title";
      authors = [
        "Test PDF Author 1"
        "Test PDF Author 2"
      ];
      subjects = [
        "Test PDF Subject 1"
        "Test PDF Subject 2"
      ];
    };
  };

  testSetsZipArg = {
    sets = [
      {
        set = {
          slug = "test-slug";
          name = "Test Name";
          conceptor = "Test Conceptor";
          kind = "Test Kind";
          contents = [ ];
        };
        pdf_metadata = {
          title = "Test PDF Title";
          authors = [
            "Test PDF Author 1"
            "Test PDF Author 2"
          ];
          subjects = [
            "Test PDF Subject 1"
            "Test PDF Subject 2"
          ];
        };
      }
    ];
    specificity = "none";
    show_set_titles = true;
    show_running_headers = true;
  };

in
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit
        (import ./renderer.nix {
          inherit (inputs) nixpkgs;
          inherit system;
        })
        makeTuneSnippets
        makeBookPdf
        makeSetPdf
        makeSetsZip
        ;
      testTuneSnippets = makeTuneSnippets testTune;
      testBookPdf = makeBookPdf testBookPdfArg;
      testSetPdf = makeSetPdf testSetPdfArg;
      testSetsZip = makeSetsZip testSetsZipArg;
    in
    {
      packages.rendererRuntime = pkgs.symlinkJoin {
        name = "renderer-runtime";
        paths =
          testTuneSnippets.buildInputs
          ++ testBookPdf.buildInputs
          ++ testSetPdf.buildInputs
          ++ testSetsZip.buildInputs;
      };

      checks.renderer-tune-snippets = testTuneSnippets;
      checks.renderer-book-pdf = testBookPdf;
      checks.renderer-set-pdf = testSetPdf;
      checks.renderer-sets-zip = testSetsZip;
    };
}
