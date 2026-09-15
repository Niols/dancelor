--
-- PostgreSQL database dump
--

\restrict ybiQOqa6jiLe8LvxFznU4q8n34iwf9VXgUBS2e7j5NMdWOEHU3ms2YSbcIZ871W

-- Dumped from database version 17.10
-- Dumped by pg_dump version 17.10

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: dancelor; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA "dancelor";


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";


--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "unaccent" WITH SCHEMA "public";


--
-- Name: actor_role; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."actor_role" AS ENUM (
    'Owner',
    'Viewer'
);


--
-- Name: globally_unique_id_type; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."globally_unique_id_type" AS ENUM (
    'Book',
    'Dance',
    'Person',
    'Set',
    'Source',
    'Tune',
    'User',
    'Version'
);


--
-- Name: kind; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."kind" AS ENUM (
    'Jig',
    'Reel',
    'Strathspey',
    'Waltz',
    'Polka',
    'Jig_9_8',
    'Other',
    'Air',
    'Hornpipe',
    'March_2_4',
    'March_4_4',
    'March_6_8',
    'Schottische',
    'Two_step'
);


--
-- Name: page_type; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."page_type" AS ENUM (
    'Part',
    'Dance_only',
    'Dance_versions',
    'Dance_set',
    'Versions',
    'Set'
);


--
-- Name: role; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."role" AS ENUM (
    'Normal_user',
    'Maintainer',
    'Administrator'
);


--
-- Name: two_chords; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."two_chords" AS ENUM (
    'Dont_know',
    'One_chord',
    'Two_chords'
);


--
-- Name: type; Type: TYPE; Schema: dancelor; Owner: -
--

CREATE TYPE "dancelor"."type" AS ENUM (
    'Person',
    'User',
    'Dance',
    'Source',
    'Tune',
    'Version',
    'Set',
    'Book'
);


--
-- Name: make_name_search("text"); Type: FUNCTION; Schema: dancelor; Owner: -
--

CREATE FUNCTION "dancelor"."make_name_search"("text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $_$ SELECT regexp_replace(lower("public"."unaccent"($1)), '^(the|an?)\s+(.+)$', '\2, \1') $_$;


--
-- Name: book; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."book" (
    "id" character varying(14) NOT NULL,
    "name" character varying NOT NULL,
    "date" character varying,
    "remark" character varying,
    "scddb_id" integer,
    "name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("name")::"text")) STORED
);


--
-- Name: book_authors; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."book_authors" (
    "book_id" character varying(14) NOT NULL,
    "author_id" character varying(14) NOT NULL
);


--
-- Name: book_content; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."book_content" (
    "book_id" character varying(14) NOT NULL,
    "index" integer NOT NULL,
    "part_title" character varying,
    "dance_id" character varying(14),
    "set_id" character varying(14),
    "set_parameter_display_name" character varying,
    "set_parameter_display_conceptor" character varying,
    "set_parameter_display_kind" character varying,
    "set_parameter_version_parameter_transposition_semitones" integer,
    "set_parameter_version_parameter_first_bar" integer,
    "set_parameter_version_parameter_clef" character varying,
    "set_parameter_version_parameter_structure" character varying,
    "set_parameter_version_parameter_trivia" character varying,
    "set_parameter_version_parameter_display_name" character varying,
    "set_parameter_version_parameter_display_composer" character varying,
    "page_type" "dancelor"."page_type" NOT NULL
);


--
-- Name: book_content_versions; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."book_content_versions" (
    "book_id" character varying(14) NOT NULL,
    "content_index" integer NOT NULL,
    "index" integer NOT NULL,
    "version_id" character varying(14) NOT NULL,
    "version_parameter_transposition_semitones" integer,
    "version_parameter_first_bar" integer,
    "version_parameter_clef" character varying,
    "version_parameter_structure" character varying,
    "version_parameter_trivia" character varying,
    "version_parameter_display_name" character varying,
    "version_parameter_display_composer" character varying
);


--
-- Name: book_sources; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."book_sources" (
    "book_id" character varying(14) NOT NULL,
    "source_id" character varying(14) NOT NULL
);


--
-- Name: dance; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."dance" (
    "id" character varying(14) NOT NULL,
    "name" character varying(256) NOT NULL,
    "kind" character varying(32) NOT NULL,
    "scddb_id" integer,
    "disambiguation" character varying(256),
    "date" character varying(32),
    "two_chords" "dancelor"."two_chords" NOT NULL,
    "name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("name")::"text")) STORED
);


--
-- Name: dance_devisers; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."dance_devisers" (
    "dance_id" character varying(14) NOT NULL,
    "index" integer NOT NULL,
    "deviser_id" character varying(14) NOT NULL
);


--
-- Name: dance_extra_names; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."dance_extra_names" (
    "dance_id" character varying(14) NOT NULL,
    "extra_name" character varying(256) NOT NULL,
    "extra_name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("extra_name")::"text")) STORED
);


--
-- Name: entry; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."entry" (
    "id" character varying(14) NOT NULL,
    "type" "dancelor"."type" NOT NULL,
    "created_at" timestamp without time zone NOT NULL,
    "modified_at" timestamp without time zone NOT NULL,
    "is_public" boolean NOT NULL
);


--
-- Name: entry_actors; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."entry_actors" (
    "entry_id" character varying(14) NOT NULL,
    "user_id" character varying(14) NOT NULL,
    "role" "dancelor"."actor_role" NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."migrations" (
    "name" character varying(255) NOT NULL,
    "applied_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: person; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."person" (
    "id" character varying(14) NOT NULL,
    "name" character varying(256) NOT NULL,
    "scddb_id" integer,
    "composed_tunes_are_public" boolean NOT NULL,
    "published_tunes_are_public" boolean NOT NULL,
    "name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("name")::"text")) STORED
);


--
-- Name: recommended_tunes; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."recommended_tunes" (
    "dance_id" character varying(14) NOT NULL,
    "tune_id" character varying(14) NOT NULL
);


--
-- Name: remember_me_tokens; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."remember_me_tokens" (
    "user_id" character varying(14) NOT NULL,
    "key" character varying(256) NOT NULL,
    "hash" character varying(256) NOT NULL,
    "max_date" timestamp without time zone NOT NULL
);


--
-- Name: set; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."set" (
    "id" character varying(14) NOT NULL,
    "name" character varying NOT NULL,
    "kind" character varying NOT NULL,
    "order" character varying NOT NULL,
    "remark" character varying,
    "name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("name")::"text")) STORED
);


--
-- Name: set_conceptors; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."set_conceptors" (
    "set_id" character varying(14) NOT NULL,
    "conceptor_id" character varying(14) NOT NULL
);


--
-- Name: set_content; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."set_content" (
    "set_id" character varying(14) NOT NULL,
    "index" integer NOT NULL,
    "version_id" character varying(14) NOT NULL,
    "version_parameter_transposition_semitones" integer,
    "version_parameter_first_bar" integer,
    "version_parameter_clef" character varying,
    "version_parameter_structure" character varying,
    "version_parameter_trivia" character varying,
    "version_parameter_display_name" character varying,
    "version_parameter_display_composer" character varying
);


--
-- Name: source; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."source" (
    "id" character varying(14) NOT NULL,
    "cover" "bytea",
    "name" character varying(256) NOT NULL,
    "short_name" character varying(64),
    "scddb_id" integer,
    "description" "text",
    "date" character varying(32),
    "name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("name")::"text")) STORED
);


--
-- Name: source_editors; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."source_editors" (
    "source_id" character varying(14) NOT NULL,
    "person_id" character varying(14) NOT NULL
);


--
-- Name: tune; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."tune" (
    "id" character varying(14) NOT NULL,
    "name" character varying NOT NULL,
    "remark" character varying,
    "scddb_id" integer,
    "date" character varying(32),
    "kind" "dancelor"."kind" NOT NULL,
    "name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("name")::"text")) STORED
);


--
-- Name: tune_composers; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."tune_composers" (
    "tune_id" character varying(14) NOT NULL,
    "index" integer NOT NULL,
    "composer_id" character varying(14) NOT NULL,
    "details" character varying
);


--
-- Name: tune_extra_names; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."tune_extra_names" (
    "tune_id" character varying(14) NOT NULL,
    "extra_name" character varying NOT NULL,
    "extra_name_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("extra_name")::"text")) STORED
);


--
-- Name: user; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."user" (
    "id" character varying(14) NOT NULL,
    "username" character varying(256) NOT NULL,
    "password" character varying(256),
    "password_reset_token_hash" character varying(256),
    "password_reset_token_max_date" timestamp without time zone,
    "omniscience" boolean NOT NULL,
    "person_id" character varying(14),
    "role" "dancelor"."role" NOT NULL,
    "username_search" "text" GENERATED ALWAYS AS ("dancelor"."make_name_search"(("username")::"text")) STORED,
    "github_handle" character varying(64)
);


--
-- Name: version; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."version" (
    "id" character varying(14) NOT NULL,
    "tune_id" character varying(14) NOT NULL,
    "key" character varying(32) NOT NULL,
    "remark" character varying,
    "disambiguation" character varying,
    "monolithic_lilypond" "text",
    "monolithic_bars" integer,
    "monolithic_or_default_structure" character varying(32),
    "destructured_as_2_4" boolean NOT NULL
);


--
-- Name: version_arrangers; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."version_arrangers" (
    "version_id" character varying(14) NOT NULL,
    "arranger_id" character varying(14) NOT NULL
);


--
-- Name: version_destructured_parts; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."version_destructured_parts" (
    "version_id" character varying(14) NOT NULL,
    "part" character varying(32) NOT NULL,
    "melody" character varying NOT NULL,
    "chords" character varying NOT NULL
);


--
-- Name: version_destructured_transitions; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."version_destructured_transitions" (
    "version_id" character varying(14) NOT NULL,
    "from_parts" character varying(32) NOT NULL,
    "to_parts" character varying(32) NOT NULL,
    "melody" character varying NOT NULL,
    "chords" character varying NOT NULL
);


--
-- Name: version_sources; Type: TABLE; Schema: dancelor; Owner: -
--

CREATE TABLE "dancelor"."version_sources" (
    "version_id" character varying(14) NOT NULL,
    "source_id" character varying(14) NOT NULL,
    "structure" character varying(32) NOT NULL,
    "details" character varying
);


--
-- Data for Name: book; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."book" ("id", "name", "date", "remark", "scddb_id") VALUES ('0fi3-1iot-6tbq', 'The Tam Lin Book', NULL, 'this is a remark', 298374872);


--
-- Data for Name: book_authors; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."book_authors" ("book_id", "author_id") VALUES ('0fi3-1iot-6tbq', '9fdg-glrm-0zoi');


--
-- Data for Name: book_content; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Versions');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 1, NULL, NULL, 'ului-yd9x-o35w', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Set');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 2, 'Dance-based stuff', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Part');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 3, NULL, 'cy5n-qvpl-k0yl', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Dance_only');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 4, NULL, '0xf7-xwz9-1fhj', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Dance_versions');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 5, NULL, 'l02q-i1j0-qpoi', 'ului-yd9x-o35w', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Dance_set');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 6, 'Private set in a public book', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Part');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 7, NULL, NULL, 'wrwk-cz9g-g3wi', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Set');
INSERT INTO "dancelor"."book_content" ("book_id", "index", "part_title", "dance_id", "set_id", "set_parameter_display_name", "set_parameter_display_conceptor", "set_parameter_display_kind", "set_parameter_version_parameter_transposition_semitones", "set_parameter_version_parameter_first_bar", "set_parameter_version_parameter_clef", "set_parameter_version_parameter_structure", "set_parameter_version_parameter_trivia", "set_parameter_version_parameter_display_name", "set_parameter_version_parameter_display_composer", "page_type") VALUES ('0fi3-1iot-6tbq', 8, NULL, '0xf7-xwz9-1fhj', 'wrwk-cz9g-g3wi', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Dance_set');


--
-- Data for Name: book_content_versions; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."book_content_versions" ("book_id", "content_index", "index", "version_id", "version_parameter_transposition_semitones", "version_parameter_first_bar", "version_parameter_clef", "version_parameter_structure", "version_parameter_trivia", "version_parameter_display_name", "version_parameter_display_composer") VALUES ('0fi3-1iot-6tbq', 0, 0, 'xzzb-wasm-babe', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "dancelor"."book_content_versions" ("book_id", "content_index", "index", "version_id", "version_parameter_transposition_semitones", "version_parameter_first_bar", "version_parameter_clef", "version_parameter_structure", "version_parameter_trivia", "version_parameter_display_name", "version_parameter_display_composer") VALUES ('0fi3-1iot-6tbq', 4, 0, 'xsbz-vqy7-xj3s', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "dancelor"."book_content_versions" ("book_id", "content_index", "index", "version_id", "version_parameter_transposition_semitones", "version_parameter_first_bar", "version_parameter_clef", "version_parameter_structure", "version_parameter_trivia", "version_parameter_display_name", "version_parameter_display_composer") VALUES ('0fi3-1iot-6tbq', 4, 1, 'jyot-ypt9-caxu', -2, 865, NULL, 'AAAAAAAAA', NULL, 'and again', 'still Niols');


--
-- Data for Name: book_sources; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."book_sources" ("book_id", "source_id") VALUES ('0fi3-1iot-6tbq', '2wrv-25yu-yc07');
INSERT INTO "dancelor"."book_sources" ("book_id", "source_id") VALUES ('0fi3-1iot-6tbq', '2f8s-90v8-33do');


--
-- Data for Name: dance; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."dance" ("id", "name", "kind", "scddb_id", "disambiguation", "date", "two_chords") VALUES ('l02q-i1j0-qpoi', 'The Architect', '8 x 32 R', NULL, NULL, NULL, 'Dont_know');
INSERT INTO "dancelor"."dance" ("id", "name", "kind", "scddb_id", "disambiguation", "date", "two_chords") VALUES ('cy5n-qvpl-k0yl', 'Test dance', '8 x 32 R', 1234, 'sdlfkj', '2188', 'Two_chords');
INSERT INTO "dancelor"."dance" ("id", "name", "kind", "scddb_id", "disambiguation", "date", "two_chords") VALUES ('0xf7-xwz9-1fhj', 'Test dance A439', '16 x 32 S', 123199, NULL, '3088', 'Two_chords');


--
-- Data for Name: dance_devisers; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."dance_devisers" ("dance_id", "index", "deviser_id") VALUES ('l02q-i1j0-qpoi', 0, '8h62-3eis-xfem');
INSERT INTO "dancelor"."dance_devisers" ("dance_id", "index", "deviser_id") VALUES ('cy5n-qvpl-k0yl', 0, 'uwoe-u6ij-ikgp');
INSERT INTO "dancelor"."dance_devisers" ("dance_id", "index", "deviser_id") VALUES ('cy5n-qvpl-k0yl', 1, '9fdg-glrm-0zoi');
INSERT INTO "dancelor"."dance_devisers" ("dance_id", "index", "deviser_id") VALUES ('cy5n-qvpl-k0yl', 2, '8h62-3eis-xfem');
INSERT INTO "dancelor"."dance_devisers" ("dance_id", "index", "deviser_id") VALUES ('0xf7-xwz9-1fhj', 0, 'uwoe-u6ij-ikgp');
INSERT INTO "dancelor"."dance_devisers" ("dance_id", "index", "deviser_id") VALUES ('0xf7-xwz9-1fhj', 1, '9fdg-glrm-0zoi');


--
-- Data for Name: dance_extra_names; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."dance_extra_names" ("dance_id", "extra_name") VALUES ('cy5n-qvpl-k0yl', 'The test dance');
INSERT INTO "dancelor"."dance_extra_names" ("dance_id", "extra_name") VALUES ('cy5n-qvpl-k0yl', 'A test dance');
INSERT INTO "dancelor"."dance_extra_names" ("dance_id", "extra_name") VALUES ('cy5n-qvpl-k0yl', 'A test dance with many names');


--
-- Data for Name: entry; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('4plf-srss-ihav', 'Person', '2018-12-07 00:18:53', '2023-06-25 14:51:15', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('8h62-3eis-xfem', 'Person', '2023-07-03 14:17:45', '2023-07-03 14:17:45', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('uwoe-u6ij-ikgp', 'Person', '2018-10-12 09:50:54', '2023-06-25 14:51:15', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('9fdg-glrm-0zoi', 'Person', '2026-05-09 13:11:10.200905', '2026-05-09 13:11:10.200905', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('lt3h-edgt-ac97', 'User', '2025-04-13 16:48:00', '2025-04-13 16:48:00', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('2f8s-90v8-33do', 'Source', '2026-05-05 20:27:49', '2026-05-05 20:27:49', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('2wrv-25yu-yc07', 'Source', '2026-05-10 11:47:17.753285', '2026-05-10 11:47:17.753285', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('l02q-i1j0-qpoi', 'Dance', '2023-12-21 18:11:33', '2023-12-21 18:11:33', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('cy5n-qvpl-k0yl', 'Dance', '2026-05-09 14:11:26', '2026-05-09 14:11:26', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('0xf7-xwz9-1fhj', 'Dance', '2026-05-10 11:36:21.52889', '2026-05-10 11:36:21.52889', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('qdod-ad7l-8gr2', 'Tune', '2018-12-07 01:18:53', '2023-06-25 15:51:15', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('rifw-ul36-3uq5', 'Tune', '2026-05-10 12:36:29', '2026-05-10 12:36:29', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('gm7o-khcu-8faz', 'Tune', '2026-05-12 12:07:47.893383', '2026-05-12 12:07:47.893383', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('xzzb-wasm-babe', 'Version', '2023-04-04 19:45:27', '2023-06-25 15:51:15', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('xsbz-vqy7-xj3s', 'Version', '2026-05-10 12:47:35', '2026-05-10 12:47:35', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('jyot-ypt9-caxu', 'Version', '2026-05-12 11:11:02', '2026-05-12 11:11:02', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('or5b-64lk-hlj5', 'Version', '2026-05-12 13:07:50', '2026-05-12 12:12:16.491412', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('ului-yd9x-o35w', 'Set', '2023-05-02 12:16:55', '2023-06-25 15:51:15', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('wrwk-cz9g-g3wi', 'Set', '2023-05-02 12:16:55', '2023-06-25 15:51:15', false);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('8x83-e8ky-bhea', 'User', '2026-09-11 15:59:59.329756', '2026-09-11 15:59:59.329756', true);
INSERT INTO "dancelor"."entry" ("id", "type", "created_at", "modified_at", "is_public") VALUES ('0fi3-1iot-6tbq', 'Book', '2026-05-14 14:40:42', '2026-09-11 16:02:09.685942', true);


--
-- Data for Name: entry_actors; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."entry_actors" ("entry_id", "user_id", "role") VALUES ('ului-yd9x-o35w', 'lt3h-edgt-ac97', 'Owner');
INSERT INTO "dancelor"."entry_actors" ("entry_id", "user_id", "role") VALUES ('wrwk-cz9g-g3wi', 'lt3h-edgt-ac97', 'Owner');
INSERT INTO "dancelor"."entry_actors" ("entry_id", "user_id", "role") VALUES ('0fi3-1iot-6tbq', '8x83-e8ky-bhea', 'Owner');


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m001_2026_04_add_book_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m002_2026_04_add_dance_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m003_2026_04_add_person_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m004_2026_04_add_set_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m005_2026_04_add_source_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m006_2026_04_add_tune_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m007_2026_04_add_user_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m008_2026_04_add_version_table', '2026-04-22 14:52:21+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m009_2026_04_add_globally_unique_id_table', '2026-04-23 23:38:30+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m010_2026_04_insert_ids_from_book_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m011_2026_04_add_fk_book_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m012_2026_04_insert_ids_from_dance_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m013_2026_04_add_fk_dance_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m014_2026_04_insert_ids_from_person_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m015_2026_04_add_fk_person_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m016_2026_04_insert_ids_from_set_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m017_2026_04_add_fk_set_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m018_2026_04_insert_ids_from_source_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m019_2026_04_add_fk_source_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m020_2026_04_insert_ids_from_tune_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m021_2026_04_add_fk_tune_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m022_2026_04_insert_ids_from_user_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m023_2026_04_add_fk_user_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m024_2026_04_insert_ids_from_version_into_globally_unique_id', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m025_2026_04_add_fk_version_id_key', '2026-04-23 23:47:34+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m026_2026_04_split_user_yaml_into_fields', '2026-04-28 09:45:10.421107+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m027_2026_04_split_role_json_into_fields', '2026-04-28 21:45:03.248478+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m028_2026_04_add_remember_me_tokens_table', '2026-04-28 21:51:55.458519+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m029_2026_04_drop_remember_me_tokens_column', '2026-04-28 21:51:55.460895+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m030_2026_05_split_person_json_into_fields', '2026-05-05 15:34:03.454472+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m031_2026_05_split_source_json_into_fields', '2026-05-07 20:33:37.340054+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m032_2026_05_split_dance_json_into_fields', '2026-05-09 13:16:31.282711+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m033_2026_05_split_tune_json_into_fields', '2026-05-10 11:48:14.488321+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m034_2026_05_split_version_json_into_fields', '2026-05-12 12:10:45.842954+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m035_2026_05_split_set_json_into_fields', '2026-05-13 10:07:34.890439+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m036_2026_05_split_book_json_into_fields', '2026-05-14 13:50:33.071361+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m037_2026_05_alter_table_set_drop_column_instructions', '2026-05-15 10:13:17.152372+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m038_2026_05_drop_table_set_dances', '2026-05-15 10:13:17.158524+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m039_2026_05_alter_table_book_rename_column_title_to_name', '2026-05-15 10:14:36.281405+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m040_2026_05_add_unique_constraint_remember_me_tokens_user_id_key', '2026-05-15 10:17:27.562229+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m041_2026_05_add_unique_constraint_source_editors_source_id_person_id', '2026-05-15 10:17:27.565783+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m042_2026_05_add_unique_constraints_dance_devisers', '2026-05-15 10:17:27.569663+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m043_2026_05_add_unique_constraints_tune_composers', '2026-05-15 10:17:27.573575+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m044_2026_05_add_unique_constraint_recommended_tunes_dance_id_tune_id', '2026-05-15 10:17:27.576845+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m045_2026_05_add_unique_constraint_version_arrangers_version_id_arranger_id', '2026-05-15 10:17:27.579686+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m046_2026_05_add_unique_constraint_version_sources_version_id_source_id_structure', '2026-05-15 10:17:27.583315+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m047_2026_05_add_unique_constraint_version_destructured_parts_version_id_part', '2026-05-15 10:17:27.58632+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m048_2026_05_add_unique_constraint_version_destructured_transitions_version_id_from_parts_to_parts', '2026-05-15 10:17:27.589172+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m049_2026_05_add_unique_constraint_set_conceptors_set_id_conceptor_id', '2026-05-15 10:17:27.59207+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m050_2026_05_add_unique_constraint_set_content_set_id_index', '2026-05-15 10:17:27.595514+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m051_2026_05_add_unique_constraint_set_viewers_set_id_viewer_id', '2026-05-15 10:17:27.598204+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m052_2026_05_add_unique_constraint_set_owners_set_id_owner_id', '2026-05-15 10:17:27.601143+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m053_2026_05_add_unique_constraint_book_authors_book_id_author_id', '2026-05-15 10:17:27.604293+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m054_2026_05_add_unique_constraint_book_sources_book_id_source_id', '2026-05-15 10:17:27.607652+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m055_2026_05_add_unique_constraint_book_content_book_id_index', '2026-05-15 10:17:27.610639+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m056_2026_05_add_unique_constraint_book_content_versions_book_id_content_index_index', '2026-05-15 10:17:27.613647+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m057_2026_05_add_unique_constraint_book_viewers_book_id_viewer_id', '2026-05-15 10:17:27.616679+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m058_2026_05_add_unique_constraint_book_owners_book_id_owner_id', '2026-05-15 10:17:27.622578+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m059_2026_05_string_to_nestring_option', '2026-05-29 14:34:07.211399+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m060_2026_06_create_extension_pg_trgm', '2026-06-09 16:38:11.371022+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m061_2026_06_use_enum_for_user_role', '2026-06-10 00:04:50.866526+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m062_2026_06_use_enum_for_two_chords', '2026-06-10 00:04:50.870731+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m063_2026_06_use_enum_for_visibility', '2026-06-10 00:04:50.874698+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m064_2026_06_use_enum_for_page_type', '2026-06-10 00:04:50.878206+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m065_2026_06_use_enum_for_type', '2026-06-10 08:14:11.873705+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m066_2026_06_rename_table_globally_unique_id', '2026-06-10 15:31:35.92784+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m067_2026_06_move_created_update_at_to_entry_table', '2026-06-12 06:56:48.092879+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m068_2026_06_move_access_to_entry_table', '2026-06-12 06:59:06.504884+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m069_2026_06_use_enum_for_tune_kind', '2026-06-13 15:45:51.895098+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m070_2026_07_name_search', '2026-07-05 23:59:27.945785+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m071_2026_07_move_pg_trgm_to_public', '2026-07-06 00:45:28.179447+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m072_2026_07_gin_indices', '2026-07-06 00:45:28.19765+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m073_2026_08_user_github_handle', '2026-08-11 10:25:47.000453+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m074_2026_09_entry_replace_visibility_by_is_public', '2026-09-11 15:57:26.490582+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m075_2026_09_entry_merge_owners_viewers_into_actors', '2026-09-11 21:35:29.47458+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m076_2026_09_version_add_destructured_as_2_4', '2026-09-15 17:05:03.672173+00');
INSERT INTO "dancelor"."migrations" ("name", "applied_at") VALUES ('m077_2026_09_add_new_kinds', '2026-09-15 17:35:34.126356+00');


--
-- Data for Name: person; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."person" ("id", "name", "scddb_id", "composed_tunes_are_public", "published_tunes_are_public") VALUES ('4plf-srss-ihav', 'Davey Arthur', NULL, true, false);
INSERT INTO "dancelor"."person" ("id", "name", "scddb_id", "composed_tunes_are_public", "published_tunes_are_public") VALUES ('8h62-3eis-xfem', 'Mervyn C Short', 347, false, false);
INSERT INTO "dancelor"."person" ("id", "name", "scddb_id", "composed_tunes_are_public", "published_tunes_are_public") VALUES ('uwoe-u6ij-ikgp', 'Nicolas “Niols” Jeannerod', 11781, true, false);
INSERT INTO "dancelor"."person" ("id", "name", "scddb_id", "composed_tunes_are_public", "published_tunes_are_public") VALUES ('9fdg-glrm-0zoi', 'John Doe', 129872873, false, false);


--
-- Data for Name: recommended_tunes; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."recommended_tunes" ("dance_id", "tune_id") VALUES ('l02q-i1j0-qpoi', 'qdod-ad7l-8gr2');
INSERT INTO "dancelor"."recommended_tunes" ("dance_id", "tune_id") VALUES ('0xf7-xwz9-1fhj', 'rifw-ul36-3uq5');


--
-- Data for Name: remember_me_tokens; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."remember_me_tokens" ("user_id", "key", "hash", "max_date") VALUES ('lt3h-edgt-ac97', '33733a85f3dd0c049d7c00bb498c1cfc', '$argon2id$v=19$m=65536,t=2,p=1$LZJ1jidMtFWhex5/c37KNw$kTcM92VAz9mjp9RKIt1xVRf/tdTmQs8vhhqnUlKCYOg', '2088-11-06 11:36:51');
INSERT INTO "dancelor"."remember_me_tokens" ("user_id", "key", "hash", "max_date") VALUES ('lt3h-edgt-ac97', '73de50d67abb397f4bbf96f2698c6e1d', '$argon2id$v=19$m=65536,t=2,p=1$sL5VHwewFdNUUHwgw+FJYg$OFSNCjlQn+33iAyo3q2hdmSFsF4X1beuDPq2eWv3SkY', '2026-11-08 10:09:09');


--
-- Data for Name: set; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."set" ("id", "name", "kind", "order", "remark") VALUES ('wrwk-cz9g-g3wi', 'A Private Set', '3x32R', '1', NULL);
INSERT INTO "dancelor"."set" ("id", "name", "kind", "order", "remark") VALUES ('ului-yd9x-o35w', 'Tam Lin Thrice', '3x32R', '1,2,3', NULL);


--
-- Data for Name: set_conceptors; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."set_conceptors" ("set_id", "conceptor_id") VALUES ('ului-yd9x-o35w', 'uwoe-u6ij-ikgp');
INSERT INTO "dancelor"."set_conceptors" ("set_id", "conceptor_id") VALUES ('wrwk-cz9g-g3wi', 'uwoe-u6ij-ikgp');


--
-- Data for Name: set_content; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."set_content" ("set_id", "index", "version_id", "version_parameter_transposition_semitones", "version_parameter_first_bar", "version_parameter_clef", "version_parameter_structure", "version_parameter_trivia", "version_parameter_display_name", "version_parameter_display_composer") VALUES ('ului-yd9x-o35w', 0, 'xzzb-wasm-babe', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "dancelor"."set_content" ("set_id", "index", "version_id", "version_parameter_transposition_semitones", "version_parameter_first_bar", "version_parameter_clef", "version_parameter_structure", "version_parameter_trivia", "version_parameter_display_name", "version_parameter_display_composer") VALUES ('ului-yd9x-o35w', 1, 'xzzb-wasm-babe', 2, NULL, NULL, NULL, NULL, NULL, NULL);
INSERT INTO "dancelor"."set_content" ("set_id", "index", "version_id", "version_parameter_transposition_semitones", "version_parameter_first_bar", "version_parameter_clef", "version_parameter_structure", "version_parameter_trivia", "version_parameter_display_name", "version_parameter_display_composer") VALUES ('ului-yd9x-o35w', 2, 'xzzb-wasm-babe', 7, NULL, NULL, NULL, NULL, NULL, NULL);


--
-- Data for Name: source; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."source" ("id", "cover", "name", "short_name", "scddb_id", "description", "date") VALUES ('2f8s-90v8-33do', NULL, 'The Tam Lin Source', 'Tam', NULL, 'this is a description', '2012-03');
INSERT INTO "dancelor"."source" ("id", "cover", "name", "short_name", "scddb_id", "description", "date") VALUES ('2wrv-25yu-yc07', NULL, 'Sourceyyyyyyyy', 'Sourcey', NULL, 'sdk', NULL);


--
-- Data for Name: source_editors; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."source_editors" ("source_id", "person_id") VALUES ('2f8s-90v8-33do', '4plf-srss-ihav');
INSERT INTO "dancelor"."source_editors" ("source_id", "person_id") VALUES ('2f8s-90v8-33do', '8h62-3eis-xfem');
INSERT INTO "dancelor"."source_editors" ("source_id", "person_id") VALUES ('2wrv-25yu-yc07', '9fdg-glrm-0zoi');


--
-- Data for Name: tune; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."tune" ("id", "name", "remark", "scddb_id", "date", "kind") VALUES ('qdod-ad7l-8gr2', 'Tam Lin', NULL, NULL, NULL, 'Reel');
INSERT INTO "dancelor"."tune" ("id", "name", "remark", "scddb_id", "date", "kind") VALUES ('rifw-ul36-3uq5', 'A439', NULL, 2398472, NULL, 'Strathspey');
INSERT INTO "dancelor"."tune" ("id", "name", "remark", "scddb_id", "date", "kind") VALUES ('gm7o-khcu-8faz', 'The Glasgow Reel', NULL, NULL, NULL, 'Reel');


--
-- Data for Name: tune_composers; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."tune_composers" ("tune_id", "index", "composer_id", "details") VALUES ('qdod-ad7l-8gr2', 0, '4plf-srss-ihav', NULL);
INSERT INTO "dancelor"."tune_composers" ("tune_id", "index", "composer_id", "details") VALUES ('rifw-ul36-3uq5', 0, 'uwoe-u6ij-ikgp', NULL);


--
-- Data for Name: tune_extra_names; Type: TABLE DATA; Schema: dancelor; Owner: -
--



--
-- Data for Name: user; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."user" ("id", "username", "password", "password_reset_token_hash", "password_reset_token_max_date", "omniscience", "person_id", "role", "github_handle") VALUES ('lt3h-edgt-ac97', 'Niols', '$argon2id$v=19$m=65536,t=2,p=1$mm4GoaR1lz2r6jJf2OomVA$VwSQPpYI6Clwh8xdoOBcwX2BFH8VCv3B++Tx1G5B11w', NULL, NULL, true, 'uwoe-u6ij-ikgp', 'Administrator', 'Niols');
INSERT INTO "dancelor"."user" ("id", "username", "password", "password_reset_token_hash", "password_reset_token_max_date", "omniscience", "person_id", "role", "github_handle") VALUES ('8x83-e8ky-bhea', 'Testouille', '$argon2id$v=19$m=65536,t=2,p=1$mm4GoaR1lz2r6jJf2OomVA$VwSQPpYI6Clwh8xdoOBcwX2BFH8VCv3B++Tx1G5B11w', NULL, NULL, false, NULL, 'Normal_user', NULL);


--
-- Data for Name: version; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."version" ("id", "tune_id", "key", "remark", "disambiguation", "monolithic_lilypond", "monolithic_bars", "monolithic_or_default_structure", "destructured_as_2_4") VALUES ('xzzb-wasm-babe', 'qdod-ad7l-8gr2', 'Dm', NULL, 'Niols''s Version', '\relative c'' <<
  {
    \clef treble
    \key d \minor
    \time 4/4

    \repeat volta 2 {
      \partial 8 r8 |
      a4 d8 a f'' a, d a |
      bes4 d8 bes f'' bes, d bes |
      c4 e8 c g'' c, e g |
      f8 e d c d c a g |
      \break

      a4 d8 a f'' a, d a |
      bes4 d8 bes f'' bes, d bes |
      c4 e8 c g'' c, e g |
      f8 e d c d4.
    } \break

    \repeat volta 2 {
      a''8 |
      d8 a a a f a d, a'' |
      d8 a a a f a d, a'' |
      c8 g g g c g e'' g, |
      c8 g g g c[ r c cis] |
      \break

      d8 a a a f a d, a'' |
      d8 a a a f[ a] d, r |
      bes8 a bes c d c d e |
      f8 e d c a[ d] d
    }
  }

  \new ChordNames {
    \chordmode {
      s8 |
      d1:m | bes | c | d2:m a:m |
      d1:m | bes | c | a2:m d4.:m

      s8 |
      d1:m | s | c | s |
      d1:m | s | g:m | a2:m d4.:m
    }
  }

  \new ChordNames {
    \chordmode {
      s8 |
      s1 | \parenthesize g:m | s | s |
      s1 | \parenthesize g:m | s | s2 s4.

      s8 |
      s1 | s | s | s |
      \parenthesize bes1 | s | s | s2 s4.
    }
  }
>>
', 32, 'AABB', false);
INSERT INTO "dancelor"."version" ("id", "tune_id", "key", "remark", "disambiguation", "monolithic_lilypond", "monolithic_bars", "monolithic_or_default_structure", "destructured_as_2_4") VALUES ('jyot-ypt9-caxu', 'rifw-ul36-3uq5', 'Dm', NULL, 'destructured', NULL, NULL, 'ABAB', false);
INSERT INTO "dancelor"."version" ("id", "tune_id", "key", "remark", "disambiguation", "monolithic_lilypond", "monolithic_bars", "monolithic_or_default_structure", "destructured_as_2_4") VALUES ('or5b-64lk-hlj5', 'gm7o-khcu-8faz', 'Dm', NULL, 'destructured w/ transitions', NULL, NULL, 'AABBAB', false);
INSERT INTO "dancelor"."version" ("id", "tune_id", "key", "remark", "disambiguation", "monolithic_lilypond", "monolithic_bars", "monolithic_or_default_structure", "destructured_as_2_4") VALUES ('xsbz-vqy7-xj3s', 'rifw-ul36-3uq5', 'Dm', NULL, NULL, NULL, NULL, NULL, false);


--
-- Data for Name: version_arrangers; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."version_arrangers" ("version_id", "arranger_id") VALUES ('xzzb-wasm-babe', 'uwoe-u6ij-ikgp');
INSERT INTO "dancelor"."version_arrangers" ("version_id", "arranger_id") VALUES ('jyot-ypt9-caxu', 'uwoe-u6ij-ikgp');


--
-- Data for Name: version_destructured_parts; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."version_destructured_parts" ("version_id", "part", "melody", "chords") VALUES ('jyot-ypt9-caxu', 'A', '\repeat volta 2 {
  a16 a8. g a16 b4 c8. b16 |
  a4 f8. e16 d4 d8. e16 |
  f4 f8. g16 e8 c4 e8 |
} \alternative { {
  d4 a'' d2 |
} {
  d,4 a'' d,
} }', 'd2:m g | d1:m | f2 c | d1:m | d2.:m');
INSERT INTO "dancelor"."version_destructured_parts" ("version_id", "part", "melody", "chords") VALUES ('jyot-ypt9-caxu', 'B', '\partial 4 a4 |
a16 d8. d c16 d8. e16 f8. a,16 |
a16 d8. d c16 d8. c16 a4 |
a16 d8. d c16 d8. e16 f8. g16 |
a16 a8. f8. c16 a''4. a,8 |
\break

a16 d8. d c16 d8. e16 f8. a,16 |
a16 d8. d c16 d8. c16 a4 |
a16 d8. d c16 d8. e16 f8. g16 |
e16 c8. g''8. e16 d2 |', 's4 | d1:m | d2:m a:m | d1:m | f |
d1:m | d2:m a:m | d1:m | c2 d:m |');
INSERT INTO "dancelor"."version_destructured_parts" ("version_id", "part", "melody", "chords") VALUES ('or5b-64lk-hlj5', 'A', 'a,4 d8 a f'' a, d a |
bes4 d8 bes f'' bes, d bes |
c4 e8 c g'' c, e g |
f8 e d c d c a g |
\break

a4 d8 a f'' a, d a |
bes4 d8 bes f'' bes, d bes |
c4 e8 c g'' c, e g |', 'd1:m | bes | c | d2:m a:m |
d1:m | bes | c |');
INSERT INTO "dancelor"."version_destructured_parts" ("version_id", "part", "melody", "chords") VALUES ('or5b-64lk-hlj5', 'B', 'd''8 a a a f a d, a'' |
d8 a a a f a d, a'' |
c8 g g g c g e'' g, |
c8 g g g c[ r c cis] |
\break

d8 a a a f a d, a'' |
d8 a a a f[ a] d, r |
bes8 a bes c d c d e |
f8 e d c a[ d] d4 |', 'd1:m | s | c | s |
d1:m | s | g:m | a2:m d:m |');


--
-- Data for Name: version_destructured_transitions; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."version_destructured_transitions" ("version_id", "from_parts", "to_parts", "melody", "chords") VALUES ('or5b-64lk-hlj5', 'A', 'A', 'f8 e d c d2 |', 'a2:m d:m |');
INSERT INTO "dancelor"."version_destructured_transitions" ("version_id", "from_parts", "to_parts", "melody", "chords") VALUES ('or5b-64lk-hlj5', 'A', 'B', 'f8 e d c d4 a'' |', 'a2:m d4:m a:7 |');
INSERT INTO "dancelor"."version_destructured_transitions" ("version_id", "from_parts", "to_parts", "melody", "chords") VALUES ('or5b-64lk-hlj5', 'start', 'A, B', '\partial 2 \tuplet 3/2 {e''4 d cis\fermata} |', 'a2:7 |');


--
-- Data for Name: version_sources; Type: TABLE DATA; Schema: dancelor; Owner: -
--

INSERT INTO "dancelor"."version_sources" ("version_id", "source_id", "structure", "details") VALUES ('xzzb-wasm-babe', '2f8s-90v8-33do', 'AABB', NULL);
INSERT INTO "dancelor"."version_sources" ("version_id", "source_id", "structure", "details") VALUES ('xsbz-vqy7-xj3s', '2wrv-25yu-yc07', 'AAAA', NULL);


--
-- Name: book idx_16409_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book"
    ADD CONSTRAINT "idx_16409_primary" PRIMARY KEY ("id");


--
-- Name: dance idx_16414_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance"
    ADD CONSTRAINT "idx_16414_primary" PRIMARY KEY ("id");


--
-- Name: migrations idx_16422_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."migrations"
    ADD CONSTRAINT "idx_16422_primary" PRIMARY KEY ("name");


--
-- Name: person idx_16426_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."person"
    ADD CONSTRAINT "idx_16426_primary" PRIMARY KEY ("id");


--
-- Name: set idx_16431_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set"
    ADD CONSTRAINT "idx_16431_primary" PRIMARY KEY ("id");


--
-- Name: source idx_16436_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."source"
    ADD CONSTRAINT "idx_16436_primary" PRIMARY KEY ("id");


--
-- Name: tune idx_16441_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune"
    ADD CONSTRAINT "idx_16441_primary" PRIMARY KEY ("id");


--
-- Name: user idx_16446_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."user"
    ADD CONSTRAINT "idx_16446_primary" PRIMARY KEY ("id");


--
-- Name: version idx_16451_primary; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version"
    ADD CONSTRAINT "idx_16451_primary" PRIMARY KEY ("id");


--
-- Name: entry pk_entry; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."entry"
    ADD CONSTRAINT "pk_entry" PRIMARY KEY ("id");


--
-- Name: book_authors uq_book_authors_book_id_author_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_authors"
    ADD CONSTRAINT "uq_book_authors_book_id_author_id" UNIQUE ("book_id", "author_id");


--
-- Name: book_content uq_book_content_book_id_index; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content"
    ADD CONSTRAINT "uq_book_content_book_id_index" UNIQUE ("book_id", "index");


--
-- Name: book_content_versions uq_book_content_versions_book_id_content_index_index; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content_versions"
    ADD CONSTRAINT "uq_book_content_versions_book_id_content_index_index" UNIQUE ("book_id", "content_index", "index");


--
-- Name: book_sources uq_book_sources_book_id_source_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_sources"
    ADD CONSTRAINT "uq_book_sources_book_id_source_id" UNIQUE ("book_id", "source_id");


--
-- Name: dance_devisers uq_dance_devisers_dance_id_deviser_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance_devisers"
    ADD CONSTRAINT "uq_dance_devisers_dance_id_deviser_id" UNIQUE ("dance_id", "deviser_id");


--
-- Name: dance_devisers uq_dance_devisers_dance_id_index_deviser_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance_devisers"
    ADD CONSTRAINT "uq_dance_devisers_dance_id_index_deviser_id" UNIQUE ("dance_id", "index", "deviser_id");


--
-- Name: entry_actors uq_entry_actors_entry_id_user_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."entry_actors"
    ADD CONSTRAINT "uq_entry_actors_entry_id_user_id" UNIQUE ("entry_id", "user_id");


--
-- Name: recommended_tunes uq_recommended_tunes_dance_id_tune_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."recommended_tunes"
    ADD CONSTRAINT "uq_recommended_tunes_dance_id_tune_id" UNIQUE ("dance_id", "tune_id");


--
-- Name: remember_me_tokens uq_remember_me_tokens_user_id_key; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."remember_me_tokens"
    ADD CONSTRAINT "uq_remember_me_tokens_user_id_key" UNIQUE ("user_id", "key");


--
-- Name: set_conceptors uq_set_conceptors_set_id_conceptor_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set_conceptors"
    ADD CONSTRAINT "uq_set_conceptors_set_id_conceptor_id" UNIQUE ("set_id", "conceptor_id");


--
-- Name: set_content uq_set_content_set_id_index; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set_content"
    ADD CONSTRAINT "uq_set_content_set_id_index" UNIQUE ("set_id", "index");


--
-- Name: source_editors uq_source_editors_source_id_person_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."source_editors"
    ADD CONSTRAINT "uq_source_editors_source_id_person_id" UNIQUE ("source_id", "person_id");


--
-- Name: tune_composers uq_tune_composers_tune_id_composer_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune_composers"
    ADD CONSTRAINT "uq_tune_composers_tune_id_composer_id" UNIQUE ("tune_id", "composer_id");


--
-- Name: tune_composers uq_tune_composers_tune_id_index_composer_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune_composers"
    ADD CONSTRAINT "uq_tune_composers_tune_id_index_composer_id" UNIQUE ("tune_id", "index", "composer_id");


--
-- Name: version_arrangers uq_version_arrangers_version_id_arranger_id; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_arrangers"
    ADD CONSTRAINT "uq_version_arrangers_version_id_arranger_id" UNIQUE ("version_id", "arranger_id");


--
-- Name: version_destructured_parts uq_version_destructured_parts_version_id_part; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_destructured_parts"
    ADD CONSTRAINT "uq_version_destructured_parts_version_id_part" UNIQUE ("version_id", "part");


--
-- Name: version_destructured_transitions uq_version_destructured_transitions_version_id_from_parts_to_pa; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_destructured_transitions"
    ADD CONSTRAINT "uq_version_destructured_transitions_version_id_from_parts_to_pa" UNIQUE ("version_id", "from_parts", "to_parts");


--
-- Name: version_sources uq_version_sources_version_id_source_id_structure; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_sources"
    ADD CONSTRAINT "uq_version_sources_version_id_source_id_structure" UNIQUE ("version_id", "source_id", "structure");


--
-- Name: user user_username_key; Type: CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."user"
    ADD CONSTRAINT "user_username_key" UNIQUE ("username");


--
-- Name: idx_book_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_book_name" ON "dancelor"."book" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_book_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_book_name_search" ON "dancelor"."book" USING "gin" ("name_search" "public"."gin_trgm_ops");


--
-- Name: idx_dance_extra_names_extra_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_dance_extra_names_extra_name" ON "dancelor"."dance_extra_names" USING "gin" ("extra_name" "public"."gin_trgm_ops");


--
-- Name: idx_dance_extra_names_extra_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_dance_extra_names_extra_name_search" ON "dancelor"."dance_extra_names" USING "gin" ("extra_name_search" "public"."gin_trgm_ops");


--
-- Name: idx_dance_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_dance_name" ON "dancelor"."dance" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_dance_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_dance_name_search" ON "dancelor"."dance" USING "gin" ("name_search" "public"."gin_trgm_ops");


--
-- Name: idx_person_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_person_name" ON "dancelor"."person" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_person_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_person_name_search" ON "dancelor"."person" USING "gin" ("name_search" "public"."gin_trgm_ops");


--
-- Name: idx_set_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_set_name" ON "dancelor"."set" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_set_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_set_name_search" ON "dancelor"."set" USING "gin" ("name_search" "public"."gin_trgm_ops");


--
-- Name: idx_source_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_source_name" ON "dancelor"."source" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_source_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_source_name_search" ON "dancelor"."source" USING "gin" ("name_search" "public"."gin_trgm_ops");


--
-- Name: idx_tune_extra_names_extra_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_tune_extra_names_extra_name" ON "dancelor"."tune_extra_names" USING "gin" ("extra_name" "public"."gin_trgm_ops");


--
-- Name: idx_tune_extra_names_extra_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_tune_extra_names_extra_name_search" ON "dancelor"."tune_extra_names" USING "gin" ("extra_name_search" "public"."gin_trgm_ops");


--
-- Name: idx_tune_name; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_tune_name" ON "dancelor"."tune" USING "gin" ("name" "public"."gin_trgm_ops");


--
-- Name: idx_tune_name_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_tune_name_search" ON "dancelor"."tune" USING "gin" ("name_search" "public"."gin_trgm_ops");


--
-- Name: idx_user_username; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_user_username" ON "dancelor"."user" USING "gin" ("username" "public"."gin_trgm_ops");


--
-- Name: idx_user_username_search; Type: INDEX; Schema: dancelor; Owner: -
--

CREATE INDEX "idx_user_username_search" ON "dancelor"."user" USING "gin" ("username_search" "public"."gin_trgm_ops");


--
-- Name: book_authors fk_book_authors_author_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_authors"
    ADD CONSTRAINT "fk_book_authors_author_id" FOREIGN KEY ("author_id") REFERENCES "dancelor"."person"("id");


--
-- Name: book_authors fk_book_authors_book_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_authors"
    ADD CONSTRAINT "fk_book_authors_book_id" FOREIGN KEY ("book_id") REFERENCES "dancelor"."book"("id");


--
-- Name: book_content fk_book_content_book_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content"
    ADD CONSTRAINT "fk_book_content_book_id" FOREIGN KEY ("book_id") REFERENCES "dancelor"."book"("id");


--
-- Name: book_content fk_book_content_dance_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content"
    ADD CONSTRAINT "fk_book_content_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dancelor"."dance"("id");


--
-- Name: book_content fk_book_content_set_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content"
    ADD CONSTRAINT "fk_book_content_set_id" FOREIGN KEY ("set_id") REFERENCES "dancelor"."set"("id");


--
-- Name: book_content_versions fk_book_content_versions_book_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content_versions"
    ADD CONSTRAINT "fk_book_content_versions_book_id" FOREIGN KEY ("book_id") REFERENCES "dancelor"."book"("id");


--
-- Name: book_content_versions fk_book_content_versions_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_content_versions"
    ADD CONSTRAINT "fk_book_content_versions_version_id" FOREIGN KEY ("version_id") REFERENCES "dancelor"."version"("id");


--
-- Name: book fk_book_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book"
    ADD CONSTRAINT "fk_book_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: book_sources fk_book_sources_book_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_sources"
    ADD CONSTRAINT "fk_book_sources_book_id" FOREIGN KEY ("book_id") REFERENCES "dancelor"."book"("id");


--
-- Name: book_sources fk_book_sources_source_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."book_sources"
    ADD CONSTRAINT "fk_book_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "dancelor"."source"("id");


--
-- Name: dance_devisers fk_dance_devisers_dance_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance_devisers"
    ADD CONSTRAINT "fk_dance_devisers_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dancelor"."dance"("id");


--
-- Name: dance_devisers fk_dance_devisers_deviser_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance_devisers"
    ADD CONSTRAINT "fk_dance_devisers_deviser_id" FOREIGN KEY ("deviser_id") REFERENCES "dancelor"."person"("id");


--
-- Name: dance_extra_names fk_dance_extra_names_dance_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance_extra_names"
    ADD CONSTRAINT "fk_dance_extra_names_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dancelor"."dance"("id");


--
-- Name: dance fk_dance_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."dance"
    ADD CONSTRAINT "fk_dance_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: entry_actors fk_entry_actors_entry_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."entry_actors"
    ADD CONSTRAINT "fk_entry_actors_entry_id" FOREIGN KEY ("entry_id") REFERENCES "dancelor"."entry"("id");


--
-- Name: entry_actors fk_entry_actors_user_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."entry_actors"
    ADD CONSTRAINT "fk_entry_actors_user_id" FOREIGN KEY ("user_id") REFERENCES "dancelor"."user"("id");


--
-- Name: person fk_person_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."person"
    ADD CONSTRAINT "fk_person_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: recommended_tunes fk_recommended_tunes_dance_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."recommended_tunes"
    ADD CONSTRAINT "fk_recommended_tunes_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dancelor"."dance"("id");


--
-- Name: recommended_tunes fk_recommended_tunes_tune_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."recommended_tunes"
    ADD CONSTRAINT "fk_recommended_tunes_tune_id" FOREIGN KEY ("tune_id") REFERENCES "dancelor"."tune"("id");


--
-- Name: set_conceptors fk_set_conceptors_conceptor_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set_conceptors"
    ADD CONSTRAINT "fk_set_conceptors_conceptor_id" FOREIGN KEY ("conceptor_id") REFERENCES "dancelor"."person"("id");


--
-- Name: set_conceptors fk_set_conceptors_set_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set_conceptors"
    ADD CONSTRAINT "fk_set_conceptors_set_id" FOREIGN KEY ("set_id") REFERENCES "dancelor"."set"("id");


--
-- Name: set_content fk_set_content_set_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set_content"
    ADD CONSTRAINT "fk_set_content_set_id" FOREIGN KEY ("set_id") REFERENCES "dancelor"."set"("id");


--
-- Name: set_content fk_set_content_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set_content"
    ADD CONSTRAINT "fk_set_content_version_id" FOREIGN KEY ("version_id") REFERENCES "dancelor"."version"("id");


--
-- Name: set fk_set_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."set"
    ADD CONSTRAINT "fk_set_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: source_editors fk_source_editors_person_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."source_editors"
    ADD CONSTRAINT "fk_source_editors_person_id" FOREIGN KEY ("person_id") REFERENCES "dancelor"."person"("id");


--
-- Name: source_editors fk_source_editors_source_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."source_editors"
    ADD CONSTRAINT "fk_source_editors_source_id" FOREIGN KEY ("source_id") REFERENCES "dancelor"."source"("id");


--
-- Name: source fk_source_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."source"
    ADD CONSTRAINT "fk_source_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: tune_composers fk_tune_composers_composer_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune_composers"
    ADD CONSTRAINT "fk_tune_composers_composer_id" FOREIGN KEY ("composer_id") REFERENCES "dancelor"."person"("id");


--
-- Name: tune_composers fk_tune_composers_tune_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune_composers"
    ADD CONSTRAINT "fk_tune_composers_tune_id" FOREIGN KEY ("tune_id") REFERENCES "dancelor"."tune"("id");


--
-- Name: tune_extra_names fk_tune_extra_names_tune_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune_extra_names"
    ADD CONSTRAINT "fk_tune_extra_names_tune_id" FOREIGN KEY ("tune_id") REFERENCES "dancelor"."tune"("id");


--
-- Name: tune fk_tune_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."tune"
    ADD CONSTRAINT "fk_tune_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: remember_me_tokens fk_user_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."remember_me_tokens"
    ADD CONSTRAINT "fk_user_id" FOREIGN KEY ("user_id") REFERENCES "dancelor"."user"("id");


--
-- Name: user fk_user_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."user"
    ADD CONSTRAINT "fk_user_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: user fk_user_person_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."user"
    ADD CONSTRAINT "fk_user_person_id" FOREIGN KEY ("person_id") REFERENCES "dancelor"."person"("id");


--
-- Name: version_arrangers fk_version_arrangers_arranger_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_arrangers"
    ADD CONSTRAINT "fk_version_arrangers_arranger_id" FOREIGN KEY ("arranger_id") REFERENCES "dancelor"."person"("id");


--
-- Name: version_arrangers fk_version_arrangers_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_arrangers"
    ADD CONSTRAINT "fk_version_arrangers_version_id" FOREIGN KEY ("version_id") REFERENCES "dancelor"."version"("id");


--
-- Name: version_destructured_parts fk_version_destructured_parts_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_destructured_parts"
    ADD CONSTRAINT "fk_version_destructured_parts_version_id" FOREIGN KEY ("version_id") REFERENCES "dancelor"."version"("id");


--
-- Name: version_destructured_transitions fk_version_destructured_transitions_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_destructured_transitions"
    ADD CONSTRAINT "fk_version_destructured_transitions_version_id" FOREIGN KEY ("version_id") REFERENCES "dancelor"."version"("id");


--
-- Name: version fk_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version"
    ADD CONSTRAINT "fk_version_id" FOREIGN KEY ("id") REFERENCES "dancelor"."entry"("id") ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: version_sources fk_version_sources_source_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_sources"
    ADD CONSTRAINT "fk_version_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "dancelor"."source"("id");


--
-- Name: version_sources fk_version_sources_version_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version_sources"
    ADD CONSTRAINT "fk_version_sources_version_id" FOREIGN KEY ("version_id") REFERENCES "dancelor"."version"("id");


--
-- Name: version fk_version_tune_id; Type: FK CONSTRAINT; Schema: dancelor; Owner: -
--

ALTER TABLE ONLY "dancelor"."version"
    ADD CONSTRAINT "fk_version_tune_id" FOREIGN KEY ("tune_id") REFERENCES "dancelor"."tune"("id");


--
-- PostgreSQL database dump complete
--

\unrestrict ybiQOqa6jiLe8LvxFznU4q8n34iwf9VXgUBS2e7j5NMdWOEHU3ms2YSbcIZ871W

