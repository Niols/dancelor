(** {1 Rendering parameters} *)

open Nes

(** The size of the paper to use. [A] allows to select the ISO 216 “A” format.
    [Custom] allows to give a custom value. The default is [A 4]. *)
type paper_size =
  | A of int
  | Custom of float * float * string (** width, height and unit *)
[@@deriving eq, show {with_path = false}, yojson]

type pdf_metadata = {
  title: string option; [@default None]
  subtitle: string option; [@default None]
  composers: string list option; [@default None] (* FIXME: difference between “author” and “composer”? *)
  subjects: string list option; [@default None] (** to be used for eg. kinds *)
}
[@@deriving fields, show, eq, yojson]

let title' = Option.value ~default: "" % title
let subtitle' = Option.value ~default: "" % subtitle
let composers' = Option.value ~default: [] % composers
let subjects' = Option.value ~default: [] % subjects

let no_pdf_metadata = Result.get_ok (pdf_metadata_of_yojson (`Assoc []))

let update_pdf_metadata ?title ?subtitle ?composers ?subjects pdf_metadata = {
  title = Option.value title ~default: Fun.id pdf_metadata.title;
  subtitle = Option.value subtitle ~default: Fun.id pdf_metadata.subtitle;
  composers = Option.value composers ~default: Fun.id pdf_metadata.composers;
  subjects = Option.value subjects ~default: Fun.id pdf_metadata.subjects;
}

let compose_pdf_metadata first second = {
  title = Option.(choose ~tie: second) first.title second.title;
  subtitle = Option.(choose ~tie: second) first.subtitle second.subtitle;
  composers = Option.(choose ~tie: second) first.composers second.composers;
  subjects = Option.(choose ~tie: second) first.subjects second.subjects;
}

type t = {
  paper_size: paper_size option; [@default None]
  instruments: string option; [@default None]
  clef: string option; [@default None]
  show_set_titles: bool option; [@default None] (** the title block at the beginning of each page/set *)
  show_running_headers: bool option; [@default None] (** the running headers and footers on each page of the PDF *)
  pdf_metadata: pdf_metadata; [@default no_pdf_metadata]
}
[@@deriving make, fields, yojson, eq, show]

let make ?paper_size ?pdf_metadata ?instruments ?clef ?show_set_titles ?show_running_headers () =
  make ~paper_size ?pdf_metadata ~instruments ~clef ~show_set_titles ~show_running_headers ()

let none = Result.get_ok (of_yojson (`Assoc []))

let paper_size' = Option.value ~default: (A 4) % paper_size
let instruments' = Option.value ~default: "" % instruments

let update ?paper_size ?pdf_metadata ?instruments ?clef ?show_set_titles ?show_headers params = {
  paper_size = Option.value paper_size ~default: Fun.id params.paper_size;
  instruments = Option.value instruments ~default: Fun.id params.instruments;
  clef = Option.value clef ~default: Fun.id params.clef;
  show_set_titles = Option.value show_set_titles ~default: Fun.id params.show_set_titles;
  show_running_headers = Option.value show_headers ~default: Fun.id params.show_running_headers;
  pdf_metadata = Option.value pdf_metadata ~default: Fun.id params.pdf_metadata;
}

let compose first second = {
  paper_size = Option.(choose ~tie: second) first.paper_size second.paper_size;
  instruments = Option.(choose ~tie: second) first.instruments second.instruments;
  clef = Option.(choose ~tie: second) first.clef second.clef;
  show_set_titles = Option.(choose ~tie: second) first.show_set_titles second.show_set_titles;
  show_running_headers = Option.(choose ~tie: second) first.show_running_headers second.show_running_headers;
  pdf_metadata = compose_pdf_metadata first.pdf_metadata second.pdf_metadata;
}
