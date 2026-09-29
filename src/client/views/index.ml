open Nes
open Html

let faq_item ?(last = false) ~id ~question body =
  div ~a: [a_class ("accordion" :: if last then ["mb-3"] else [])] [
    div ~a: [a_class ["accordion-item"]] [
      h2 ~a: [a_class ["accordion-header"]] [
        button
          ~a: [
            a_class ["accordion-button"; "collapsed"];
            a_button_type `Button;
            a_user_data "bs-toggle" "collapse";
            a_user_data "bs-target" ("#" ^ id);
            a_aria "expanded" ["false"];
            a_aria "controls" [id];
          ]
          [txt question]
      ];
      div
        ~a: [
          a_id id;
          a_class ["accordion-collapse"; "collapse"];
        ]
        [div ~a: [a_class ["accordion-body"]] body]
    ]
  ]

let create () =
  Page.make'
    ~title: (lwt "Welcome to Dancelor!")
    [
      p [
        txt "Dancelor is a community-edited database of Scottish country dance music. ";
        txt "Search for tunes, sets, books, and more; ";
        txt "add your own tunes and assemble them into sets and books; ";
        txt "export everything to PDF, ready to print and bring to the dance; ";
        txt "and share with your fellow musicians. ";
        txt "Whether you are a seasoned band leader or a musician just starting out, ";
        a ~a: [a_href @@ Uri.of_string "/explore"] [txt "come explore the database"];
        txt "!"
      ];
      R.section (
        let title_and_table t = [
          h4 [txt "Continue where you left off"];
          div ~a: [a_class ["mb-3"]] t
        ]
        in
        let length = 15 in
        S.from_lwt (title_and_table (Utils.Tables.placeholder ~rows: length ())) @@
          match%lwt History.get_models () with
          | [] -> lwt_nil
          | history -> lwt (title_and_table [Utils.Tables.any @@ List.take length history])
      );
      section [
        h4 [txt "Most recently added"];
        R.div ~a: [a_class ["mb-3"]] (
          let length = 15 in
          S.from_lwt (Utils.Tables.placeholder ~rows: length ()) @@
            let%lwt newest = Api.call_exn (Any Newest) length in
            lwt [Utils.Tables.any newest]
        );
      ];
      section [
        h4 [txt "Frequently asked questions"];
        h5 [txt "About Dancelor"];
        faq_item ~id: "faq-kinds" ~question: "What kinds of tunes are in Dancelor?" [
          p [
            txt "Dancelor focuses on the Scottish country dance repertoire: ";
            txt "reels, jigs, strathspeys, and more. ";
            txt "You will find both well-known classics and less common tunes, ";
            txt "including original compositions by members of the community."
          ]
        ];
        faq_item ~id: "faq-performance" ~question: "Can I use Dancelor for a performance?" [
          p [
            txt "Absolutely — that is how Dancelor started! ";
            txt "The Paris Branch SCD Band uses Dancelor exclusively for all its performances ";
            txt "and has been doing so for close to 10 years. ";
            txt "Export your sets and books to PDF, print them out, and you are good to go."
          ]
        ];
        faq_item ~id: "faq-scddb" ~question: "How is Dancelor different from the SCDDB?" [
          p [
            txt "The SCDDB (";
            a ~a: [a_href Dancelor_common.SCDDB.root] [txt "my.strathspey.org"];
            txt ") is the most comprehensive database of metadata for Scottish country ";
            txt "dancing, and we love it! ";
            txt "However, the SCDDB does not host sheet music. ";
            txt "Dancelor complements it by providing the sheet music that musicians need. ";
            txt "From most items in Dancelor, you can visit the corresponding SCDDB page in one click."
          ]
        ];
        faq_item ~id: "faq-scd-only" ~question: "Is Dancelor only for Scottish country dancing?" [
          p [
            txt "Dancelor has been made by SCD musicians for SCD musicians, ";
            txt "but everyone is welcome! ";
            txt "Some features like sets are a bit specific to SCD, ";
            txt "where each dance calls for a precise sequence of tunes. ";
            txt "Session musicians, who might play the same tune on repeat or play more by ear, ";
            txt "may find them less useful — but the tune database itself is for everyone."
          ]
        ];
        faq_item ~id: "faq-free" ~question: "Is Dancelor free?" [
          p [
            txt "Yes! Dancelor is not only free to use, it is also ";
            a ~a: [a_href @@ Uri.of_string "https://www.gnu.org/philosophy/free-sw.html"] [txt "free as in freedom"];
            txt ": the source code is open and available on ";
            a ~a: [a_href @@ Uri.of_string "https://github.com/niols/dancelor"] [txt "GitHub"];
            txt ". The database of tunes, however, is not publicly downloadable, ";
            txt "mostly to protect copyrighted content."
          ]
        ];
        faq_item ~last: true ~id: "faq-who" ~question: "Who makes Dancelor?" [
          p [
            txt "Dancelor is an open source project, primarily developed by Niols. ";
            txt "Contributions and feedback are always welcome!";
          ]
        ];
        h5 [txt "Getting involved"];
        faq_item ~id: "faq-account" ~question: "How do I get an account?" [
          p [
            txt "There is no public sign-up at the moment. ";
            txt "If you would like an account, please reach out to Niols directly ";
            txt "or use the \"Report an issue\" button. ";
            txt "With an account, you can add your own tunes to the database ";
            txt "and get access to content that other musicians have shared with you."
          ]
        ];
        faq_item ~id: "faq-contribute" ~question: "How do I contribute tunes?" [
          p [
            txt "Once you have an account, you can add tunes directly from the website. ";
            txt "Tune contents are entered in a simplified version of the ";
            a ~a: [a_href @@ Uri.of_string "https://lilypond.org"] [txt "LilyPond"];
            txt " notation, a free music engraving program. ";
            txt "If you are unsure about anything, feel free to \"Report an issue\"; we will help."
          ]
        ];
        faq_item ~last: true ~id: "faq-lilypond" ~question: "Do I need to know LilyPond to use Dancelor?" [
          p [
            txt "Not at all! LilyPond is only needed to add new tunes to the database. ";
            txt "For browsing, searching, creating sets and books, and exporting to PDF, ";
            txt "no technical knowledge is required. ";
            txt "And even for adding tunes, we use such a tiny portion of LilyPond that it is easy to pick up."
          ]
        ];
        h5 [txt "Feedback and contact"];
        faq_item ~id: "faq-mistake" ~question: "I found a mistake, or a tune is missing!" [
          p [
            txt "Please let us know! You can use the \"Report an issue\" button ";
            txt "at the bottom of each page or ";
            a ~a: [a_href @@ Uri.of_string "https://github.com/niols/dancelor/issues"] [txt "open an issue on GitHub"];
            txt ". Whether it is a wrong note, a missing tune, or incorrect metadata, ";
            txt "we appreciate every report."
          ]
        ];
        faq_item ~id: "faq-feature" ~question: "I have an idea for a feature or improvement!" [
          p [
            txt "We would love to hear it! Use the \"Report an issue\" button ";
            txt "at the bottom of any page to let us know."
          ]
        ];
        faq_item ~last: true ~id: "faq-copyright" ~question: "What if a tune on Dancelor infringes copyright?" [
          p [
            txt "We take copyright very seriously. ";
            txt "If you believe that a tune on Dancelor has been posted without proper authorisation, ";
            txt "or made public when it is not supposed to be available, ";
            txt "please report an issue immediately and we will act on it promptly.";
          ]
        ];
      ];
    ]
