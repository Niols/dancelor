CREATE TYPE "type" AS ENUM ('Person', 'User', 'Dance', 'Source', 'Tune', 'Version', 'Set', 'Book');

CREATE TABLE "entry" (
    -- [sqlgg] module=Sql_types.Entry_id_conv
    "id" VARCHAR(14) NOT NULL,
    "type" "type" NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "modified_at" TIMESTAMP NOT NULL,
    "is_public" BOOLEAN NOT NULL,
    CONSTRAINT "pk_entry" PRIMARY KEY ("id")
);

CREATE TABLE "person" (
    -- [sqlgg] module=Sql_types.Person_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "name" VARCHAR(256) NOT NULL,
    "scddb_id" INT,
    "composed_tunes_are_public" BOOLEAN NOT NULL,
    "published_tunes_are_public" BOOLEAN NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "fk_person_id" FOREIGN KEY ("id") REFERENCES "entry" ("id")
);

CREATE TYPE "role" AS ENUM ('Normal_user', 'Maintainer', 'Administrator');

CREATE TABLE "user" (
    -- [sqlgg] module=Sql_types.User_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "username" VARCHAR(256) NOT NULL UNIQUE,
    "password" VARCHAR(256),
    "password_reset_token_hash" VARCHAR(256),
    "password_reset_token_max_date" TIMESTAMP,
    "omniscience" BOOLEAN NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "person_id" VARCHAR(14) NULL,
    "role" "role" NOT NULL,
    "username_search" TEXT GENERATED ALWAYS AS (make_name_search("username")) STORED,
    "github_handle" VARCHAR(64),
    CONSTRAINT "fk_user_id" FOREIGN KEY ("id") REFERENCES "entry" ("id"),
    CONSTRAINT "fk_user_person_id" FOREIGN KEY ("person_id") REFERENCES "person" ("id")
);

CREATE TABLE "entry_viewers" (
    -- [sqlgg] module=Sql_types.Entry_id_conv
    "entry_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.User_id_conv
    "viewer_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_entry_viewers_entry_id" FOREIGN KEY ("entry_id") REFERENCES "entry" ("id"),
    CONSTRAINT "fk_entry_viewers_viewer_id" FOREIGN KEY ("viewer_id") REFERENCES "user" ("id"),
    CONSTRAINT "uq_entry_viewers_entry_id_viewer_id" UNIQUE ("entry_id", "viewer_id")
);

CREATE TABLE "entry_owners" (
    -- [sqlgg] module=Sql_types.Entry_id_conv
    "entry_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.User_id_conv
    "owner_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_entry_owners_entry_id" FOREIGN KEY ("entry_id") REFERENCES "entry" ("id"),
    CONSTRAINT "fk_entry_owners_owner_id" FOREIGN KEY ("owner_id") REFERENCES "user" ("id"),
    CONSTRAINT "uq_entry_owners_entry_id_owner_id" UNIQUE ("entry_id", "owner_id")
);

CREATE TABLE "remember_me_tokens" (
    -- [sqlgg] module=Sql_types.User_id_conv
    "user_id" VARCHAR(14) NOT NULL,
    "key" VARCHAR(256) NOT NULL,
    "hash" VARCHAR(256) NOT NULL,
    "max_date" TIMESTAMP NOT NULL,
    CONSTRAINT "fk_user_id" FOREIGN KEY ("user_id") REFERENCES "user" ("id"),
    CONSTRAINT "uq_remember_me_tokens_user_id_key" UNIQUE ("user_id", "key")
);

CREATE TABLE "source" (
    -- [sqlgg] module=Sql_types.Source_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "cover" BYTEA DEFAULT NULL,
    "name" VARCHAR(256) NOT NULL,
    "short_name" VARCHAR(64),
    "scddb_id" INT,
    "description" TEXT,
    "date" VARCHAR(32),
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "fk_source_id" FOREIGN KEY ("id") REFERENCES "entry" ("id")
);

CREATE TABLE "source_editors" (
    -- [sqlgg] module=Sql_types.Source_id_conv
    "source_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "person_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_source_editors_source_id" FOREIGN KEY ("source_id") REFERENCES "source" ("id"),
    CONSTRAINT "fk_source_editors_person_id" FOREIGN KEY ("person_id") REFERENCES "person" ("id"),
    CONSTRAINT "uq_source_editors_source_id_person_id" UNIQUE ("source_id", "person_id")
);

CREATE TYPE "two_chords" AS ENUM ('Dont_know', 'One_chord', 'Two_chords');

CREATE TABLE "dance" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "name" VARCHAR(256) NOT NULL,
    "kind" VARCHAR(32) NOT NULL,
    "scddb_id" INT,
    "disambiguation" VARCHAR(256),
    "date" VARCHAR(32),
    "two_chords" "two_chords" NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "fk_dance_id" FOREIGN KEY ("id") REFERENCES "entry" ("id")
);

CREATE TABLE "dance_devisers" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "deviser_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_dance_devisers_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id"),
    CONSTRAINT "fk_dance_devisers_deviser_id" FOREIGN KEY ("deviser_id") REFERENCES "person" ("id"),
    CONSTRAINT "uq_dance_devisers_dance_id_deviser_id" UNIQUE ("dance_id", "deviser_id"),
    CONSTRAINT "uq_dance_devisers_dance_id_index_deviser_id" UNIQUE ("dance_id", "index", "deviser_id")
);

CREATE TABLE "dance_extra_names" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14) NOT NULL,
    "extra_name" VARCHAR(256) NOT NULL,
    "extra_name_search" TEXT GENERATED ALWAYS AS (make_name_search("extra_name")) STORED,
    CONSTRAINT "fk_dance_extra_names_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id")
);

CREATE TYPE "kind" AS ENUM ('Jig', 'Reel', 'Strathspey', 'Waltz', 'Polka', 'Jig_9_8', 'Other');

CREATE TABLE "tune" (
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "name" VARCHAR NOT NULL,
    "remark" VARCHAR,
    "scddb_id" INT,
    "date" VARCHAR(32),
    "kind" "kind" NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "fk_tune_id" FOREIGN KEY ("id") REFERENCES "entry" ("id")
);

CREATE TABLE "tune_extra_names" (
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    "extra_name" VARCHAR NOT NULL,
    "extra_name_search" TEXT GENERATED ALWAYS AS (make_name_search("extra_name")) STORED,
    CONSTRAINT "fk_tune_extra_names_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id")
);

CREATE TABLE "tune_composers" (
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "composer_id" VARCHAR(14) NOT NULL,
    "details" VARCHAR,
    CONSTRAINT "fk_tune_composers_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id"),
    CONSTRAINT "fk_tune_composers_composer_id" FOREIGN KEY ("composer_id") REFERENCES "person" ("id"),
    CONSTRAINT "uq_tune_composers_tune_id_composer_id" UNIQUE ("tune_id", "composer_id"),
    CONSTRAINT "uq_tune_composers_tune_id_index_composer_id" UNIQUE ("tune_id", "index", "composer_id")
);

CREATE TABLE "recommended_tunes" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_recommended_tunes_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id"),
    CONSTRAINT "fk_recommended_tunes_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id"),
    CONSTRAINT "uq_recommended_tunes_dance_id_tune_id" UNIQUE ("dance_id", "tune_id")
);

CREATE TABLE "version" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    "key" VARCHAR(32) NOT NULL,
    "remark" VARCHAR,
    "disambiguation" VARCHAR,
    "monolithic_lilypond" TEXT,
    "monolithic_bars" INT,
    "monolithic_or_default_structure" VARCHAR(32),
    CONSTRAINT "fk_version_id" FOREIGN KEY ("id") REFERENCES "entry" ("id"),
    CONSTRAINT "fk_version_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id")
);

CREATE TABLE "version_arrangers" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "arranger_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_version_arrangers_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "fk_version_arrangers_arranger_id" FOREIGN KEY ("arranger_id") REFERENCES "person" ("id"),
    CONSTRAINT "uq_version_arrangers_version_id_arranger_id" UNIQUE ("version_id", "arranger_id")
);

CREATE TABLE "version_sources" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Source_id_conv
    "source_id" VARCHAR(14) NOT NULL,
    "structure" VARCHAR(32) NOT NULL,
    "details" VARCHAR,
    CONSTRAINT "fk_version_sources_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "fk_version_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "source" ("id"),
    CONSTRAINT "uq_version_sources_version_id_source_id_structure" UNIQUE ("version_id", "source_id" ,"structure")
);

CREATE TABLE "version_destructured_parts" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    "part" VARCHAR(32) NOT NULL,
    "melody" VARCHAR NOT NULL,
    "chords" VARCHAR NOT NULL,
    CONSTRAINT "fk_version_destructured_parts_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "uq_version_destructured_parts_version_id_part" UNIQUE ("version_id", "part")
);

CREATE TABLE "version_destructured_transitions" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    "from_parts" VARCHAR(32) NOT NULL,
    "to_parts" VARCHAR(32) NOT NULL,
    "melody" VARCHAR NOT NULL,
    "chords" VARCHAR NOT NULL,
    CONSTRAINT "fk_version_destructured_transitions_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "uq_version_destructured_transitions_version_id_from_parts_to_parts" UNIQUE ("version_id", "from_parts", "to_parts")
);

CREATE TABLE "set" (
    -- [sqlgg] module=Sql_types.Set_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "name" VARCHAR NOT NULL,
    "kind" VARCHAR NOT NULL,
    "order" VARCHAR NOT NULL,
    "remark" VARCHAR,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "fk_set_id" FOREIGN KEY ("id") REFERENCES "entry" ("id")
);

CREATE TABLE "set_conceptors" (
    -- [sqlgg] module=Sql_types.Set_id_conv
    "set_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "conceptor_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_set_conceptors_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_conceptors_conceptor_id" FOREIGN KEY ("conceptor_id") REFERENCES "person" ("id"),
    CONSTRAINT "uq_set_conceptors_set_id_conceptor_id" UNIQUE ("set_id", "conceptor_id")
);

CREATE TABLE "set_content" (
    -- [sqlgg] module=Sql_types.Set_id_conv
    "set_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    "version_parameter_transposition_semitones" INT,
    "version_parameter_first_bar" INT,
    "version_parameter_clef" VARCHAR,
    "version_parameter_structure" VARCHAR,
    "version_parameter_trivia" VARCHAR,
    "version_parameter_display_name" VARCHAR,
    "version_parameter_display_composer" VARCHAR,
    CONSTRAINT "fk_set_content_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_content_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "uq_set_content_set_id_index" UNIQUE ("set_id", "index")
);

CREATE TABLE "book" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "id" VARCHAR(14) NOT NULL PRIMARY KEY,
    "name" VARCHAR NOT NULL,
    "date" VARCHAR,
    "remark" VARCHAR,
    "scddb_id" INT,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "fk_book_id" FOREIGN KEY ("id") REFERENCES "entry" ("id")
);

CREATE TABLE "book_authors" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "book_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "author_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_book_authors_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_authors_author_id" FOREIGN KEY ("author_id") REFERENCES "person" ("id"),
    CONSTRAINT "uq_book_authors_book_id_author_id" UNIQUE ("book_id", "author_id")
);

CREATE TABLE "book_sources" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "book_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Source_id_conv
    "source_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_book_sources_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "source" ("id"),
    CONSTRAINT "uq_book_sources_book_id_source_id" UNIQUE ("book_id", "source_id")
);

CREATE TYPE "page_type" AS ENUM ('Part', 'Dance_only', 'Dance_versions', 'Dance_set', 'Versions', 'Set');

CREATE TABLE "book_content" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "book_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    "part_title" VARCHAR,
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14),
    -- [sqlgg] module=Sql_types.Set_id_conv
    "set_id" VARCHAR(14), -- standalone or within dance
    "set_parameter_display_name" VARCHAR,
    "set_parameter_display_conceptor" VARCHAR,
    "set_parameter_display_kind" VARCHAR,
    "set_parameter_version_parameter_transposition_semitones" INT,
    "set_parameter_version_parameter_first_bar" INT,
    "set_parameter_version_parameter_clef" VARCHAR,
    "set_parameter_version_parameter_structure" VARCHAR,
    "set_parameter_version_parameter_trivia" VARCHAR,
    "set_parameter_version_parameter_display_name" VARCHAR,
    "set_parameter_version_parameter_display_composer" VARCHAR,
    "page_type" "page_type" NOT NULL,
    CONSTRAINT "fk_book_content_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_content_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id"),
    CONSTRAINT "fk_book_content_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "uq_book_content_book_id_index" UNIQUE ("book_id", "index")
);

CREATE TABLE "book_content_versions" ( -- standalone or within dance
    -- [sqlgg] module=Sql_types.Book_id_conv
    "book_id" VARCHAR(14) NOT NULL,
    "content_index" INT NOT NULL,
    "index" INT NOT NULL,
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    "version_parameter_transposition_semitones" INT,
    "version_parameter_first_bar" INT,
    "version_parameter_clef" VARCHAR,
    "version_parameter_structure" VARCHAR,
    "version_parameter_trivia" VARCHAR,
    "version_parameter_display_name" VARCHAR,
    "version_parameter_display_composer" VARCHAR,
    CONSTRAINT "fk_book_content_versions_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_content_versions_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "uq_book_content_versions_book_id_content_index_index" UNIQUE ("book_id", "content_index", "index")
);
