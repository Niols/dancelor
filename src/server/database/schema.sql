-- Dancelor's PostgreSQL database schema

-- ---------- [ Entities ] ---------- --

CREATE TYPE "type" AS ENUM ('Person', 'User', 'Dance', 'Source', 'Tune', 'Version', 'Set', 'Book', 'Group');

CREATE TABLE "entities" (
    -- [sqlgg] module=Sql_types.Untagged_id_conv
    "id" VARCHAR(14) NOT NULL,
    "type" "type" NOT NULL,
    "created_at" TIMESTAMP NOT NULL,
    "modified_at" TIMESTAMP NOT NULL,
    "is_public" BOOLEAN NOT NULL,
    CONSTRAINT "pk_entities" PRIMARY KEY ("id")
);

-- ---------- [ Principals ] ---------- --

CREATE TYPE "role" AS ENUM ('Normal_user', 'Maintainer', 'Administrator');

CREATE TABLE "users" (
    -- [sqlgg] module=Sql_types.User_id_conv
    "id" VARCHAR(14) NOT NULL,
    "username" VARCHAR(256) NOT NULL,
    -- [sqlgg] module=Sql_types.Password_conv
    "password" VARCHAR(256),
    -- [sqlgg] module=Sql_types.Password_reset_token_hash_conv
    "password_reset_token_hash" VARCHAR(256),
    "password_reset_token_max_date" TIMESTAMP,
    "omniscience" BOOLEAN NOT NULL,
    -- [sqlgg] module=Sql_types.Role_conv
    "role" "role" NOT NULL,
    "username_search" TEXT GENERATED ALWAYS AS (make_name_search("username")) STORED,
    "github_handle" VARCHAR(64),
    -- [sqlgg] module=Sql_types.Email_conv
    "email" VARCHAR(256) NOT NULL,
    "email_verified" BOOLEAN NOT NULL DEFAULT FALSE,
    "full_name" VARCHAR(256),
    CONSTRAINT "pk_users" PRIMARY KEY ("id"),
    CONSTRAINT "uq_users_username" UNIQUE ("username"),
    CONSTRAINT "uq_users_email" UNIQUE ("email"),
    CONSTRAINT "fk_users_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_users_username" ON "users" USING GIN ("username" "public"."gin_trgm_ops");
CREATE INDEX "idx_users_username_search" ON "users" USING GIN ("username_search" "public"."gin_trgm_ops");

CREATE TABLE "groups" (
    -- [sqlgg] module=Sql_types.Group_id_conv
    "id" VARCHAR(14) NOT NULL,
    "name" VARCHAR(256) NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    "description" TEXT,
    CONSTRAINT "pk_groups" PRIMARY KEY ("id"),
    CONSTRAINT "fk_groups_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE TYPE "group_member_role" AS ENUM ('Group_admin', 'Regular_member');

CREATE TABLE "group_members" (
    -- [sqlgg] module=Sql_types.Group_id_conv
    "group_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.User_id_conv
    "member_id" VARCHAR(14) NOT NULL,
    "member_role" "group_member_role" NOT NULL DEFAULT 'Regular_member',
    CONSTRAINT "uq_group_members_group_id_member_id" UNIQUE ("group_id", "member_id"),
    CONSTRAINT "fk_group_members_group_id" FOREIGN KEY ("group_id") REFERENCES "groups" ("id"),
    CONSTRAINT "fk_group_members_member_id" FOREIGN KEY ("member_id") REFERENCES "users" ("id")
);

CREATE INDEX "idx_group_members_member_id" ON "group_members" ("member_id");

-- NOTE: The order matters, and stronger roles should appear before weaker ones
-- such that `<` can be used to compare them.
CREATE TYPE "actor_role" AS ENUM ('Owner', 'Viewer');

CREATE TABLE "entity_actors" (
    -- [sqlgg] module=Sql_types.Untagged_id_conv
    "entity_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.User_id_conv
    "user_id" VARCHAR(14),
    -- [sqlgg] module=Sql_types.Actor_role_conv
    "role" "actor_role" NOT NULL,
    -- [sqlgg] module=Sql_types.Group_id_conv
    "group_id" VARCHAR(14),
    CONSTRAINT "uq_entity_actors_entity_id_user_id_group_id" UNIQUE ("entity_id", "user_id", "group_id"),
    CONSTRAINT "fk_entity_actors_entity_id" FOREIGN KEY ("entity_id") REFERENCES "entities" ("id"),
    CONSTRAINT "fk_entity_actors_user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id")
    -- INVARIANT: user_id IS NULL <=> group_id IS NOT NULL
);

CREATE INDEX "idx_entity_actors_user_id" ON "entity_actors" ("user_id");
CREATE INDEX "idx_entity_actors_group_id" ON "entity_actors" ("group_id");

-- ---------- [ Resources ] ---------- --

CREATE TABLE "persons" (
    -- [sqlgg] module=Sql_types.Person_id_conv
    "id" VARCHAR(14) NOT NULL,
    "name" VARCHAR(256) NOT NULL,
    "scddb_id" INT,
    "composed_tunes_are_public" BOOLEAN NOT NULL,
    "published_tunes_are_public" BOOLEAN NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    "copyright_name" VARCHAR(256),
    CONSTRAINT "pk_persons" PRIMARY KEY ("id"),
    CONSTRAINT "fk_persons_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_persons_name" ON "persons" USING GIN ("name" "public"."gin_trgm_ops");
CREATE INDEX "idx_persons_name_search" ON "persons" USING GIN ("name_search" "public"."gin_trgm_ops");

CREATE TABLE "user_persons" (
    -- [sqlgg] module=Sql_types.User_id_conv
    "user_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "person_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_user_persons_user_id" UNIQUE ("user_id"),
    CONSTRAINT "uq_user_persons_person_id" UNIQUE ("person_id"),
    CONSTRAINT "fk_user_persons_user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id"),
    CONSTRAINT "fk_user_persons_person_id" FOREIGN KEY ("person_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_user_persons_user_id" ON "user_persons" ("user_id");
CREATE INDEX "idx_user_persons_person_id" ON "user_persons" ("person_id");

CREATE TABLE "remember_me_tokens" (
    -- [sqlgg] module=Sql_types.User_id_conv
    "user_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Remember_me_key_conv
    "key" VARCHAR(256) NOT NULL,
    -- [sqlgg] module=Sql_types.Remember_me_token_hash_conv
    "hash" VARCHAR(256) NOT NULL,
    "max_date" TIMESTAMP NOT NULL,
    CONSTRAINT "uq_remember_me_tokens_user_id_key" UNIQUE ("user_id", "key"),
    CONSTRAINT "fk_remember_me_tokens_user_id" FOREIGN KEY ("user_id") REFERENCES "users" ("id")
);

CREATE TABLE "sources" (
    -- [sqlgg] module=Sql_types.Source_id_conv
    "id" VARCHAR(14) NOT NULL,
    "cover" BYTEA DEFAULT NULL,
    "name" VARCHAR(256) NOT NULL,
    "short_name" VARCHAR(64),
    "scddb_id" INT,
    "description" TEXT,
    "date" VARCHAR(32),
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "pk_sources" PRIMARY KEY ("id"),
    CONSTRAINT "fk_sources_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_sources_name" ON "sources" USING GIN ("name" "public"."gin_trgm_ops");
CREATE INDEX "idx_sources_name_search" ON "sources" USING GIN ("name_search" "public"."gin_trgm_ops");

CREATE TABLE "source_editors" (
    -- [sqlgg] module=Sql_types.Source_id_conv
    "source_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "person_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_source_editors_source_id_person_id" UNIQUE ("source_id", "person_id"),
    CONSTRAINT "fk_source_editors_source_id" FOREIGN KEY ("source_id") REFERENCES "sources" ("id"),
    CONSTRAINT "fk_source_editors_person_id" FOREIGN KEY ("person_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_source_editors_person_id" ON "source_editors" ("person_id");

CREATE TYPE "two_chords" AS ENUM ('Dont_know', 'One_chord', 'Two_chords');

CREATE TABLE "dances" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "id" VARCHAR(14) NOT NULL,
    "name" VARCHAR(256) NOT NULL,
    "kind" VARCHAR(32) NOT NULL,
    "scddb_id" INT,
    "disambiguation" VARCHAR(256),
    "date" VARCHAR(32),
    -- [sqlgg] module=Sql_types.Two_chords_conv
    "two_chords" "two_chords" NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "pk_dances" PRIMARY KEY ("id"),
    CONSTRAINT "fk_dances_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_dances_name" ON "dances" USING GIN ("name" "public"."gin_trgm_ops");
CREATE INDEX "idx_dances_name_search" ON "dances" USING GIN ("name_search" "public"."gin_trgm_ops");

CREATE TABLE "dance_devisers" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "deviser_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_dance_devisers_dance_id_deviser_id" UNIQUE ("dance_id", "deviser_id"),
    CONSTRAINT "uq_dance_devisers_dance_id_index_deviser_id" UNIQUE ("dance_id", "index", "deviser_id"),
    CONSTRAINT "fk_dance_devisers_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dances" ("id"),
    CONSTRAINT "fk_dance_devisers_deviser_id" FOREIGN KEY ("deviser_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_dance_devisers_deviser_id" ON "dance_devisers" ("deviser_id");

CREATE TABLE "dance_extra_names" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14) NOT NULL,
    "extra_name" VARCHAR(256) NOT NULL,
    "extra_name_search" TEXT GENERATED ALWAYS AS (make_name_search("extra_name")) STORED,
    CONSTRAINT "fk_dance_extra_names_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dances" ("id")
);

CREATE INDEX "idx_dance_extra_names_dance_id" ON "dance_extra_names" ("dance_id");
CREATE INDEX "idx_dance_extra_names_extra_name" ON "dance_extra_names" USING GIN ("extra_name" "public"."gin_trgm_ops");
CREATE INDEX "idx_dance_extra_names_extra_name_search" ON "dance_extra_names" USING GIN ("extra_name_search" "public"."gin_trgm_ops");

CREATE TYPE "kind" AS ENUM (
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

CREATE TABLE "tunes" (
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "id" VARCHAR(14) NOT NULL,
    "name" VARCHAR NOT NULL,
    "remark" VARCHAR,
    "scddb_id" INT,
    "date" VARCHAR(32),
    -- [sqlgg] module=Sql_types.Kind_conv
    "kind" "kind" NOT NULL,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "pk_tunes" PRIMARY KEY ("id"),
    CONSTRAINT "fk_tunes_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_tunes_name" ON "tunes" USING GIN ("name" "public"."gin_trgm_ops");
CREATE INDEX "idx_tunes_name_search" ON "tunes" USING GIN ("name_search" "public"."gin_trgm_ops");

CREATE TABLE "tune_extra_names" (
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    "extra_name" VARCHAR NOT NULL,
    "extra_name_search" TEXT GENERATED ALWAYS AS (make_name_search("extra_name")) STORED,
    CONSTRAINT "fk_tune_extra_names_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tunes" ("id")
);

CREATE INDEX "idx_tune_extra_names_tune_id" ON "tune_extra_names" ("tune_id");
CREATE INDEX "idx_tune_extra_names_extra_name" ON "tune_extra_names" USING GIN ("extra_name" "public"."gin_trgm_ops");
CREATE INDEX "idx_tune_extra_names_extra_name_search" ON "tune_extra_names" USING GIN ("extra_name_search" "public"."gin_trgm_ops");

CREATE TABLE "tune_composers" (
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "composer_id" VARCHAR(14) NOT NULL,
    "details" VARCHAR,
    CONSTRAINT "uq_tune_composers_tune_id_composer_id" UNIQUE ("tune_id", "composer_id"),
    CONSTRAINT "uq_tune_composers_tune_id_index_composer_id" UNIQUE ("tune_id", "index", "composer_id"),
    CONSTRAINT "fk_tune_composers_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tunes" ("id"),
    CONSTRAINT "fk_tune_composers_composer_id" FOREIGN KEY ("composer_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_tune_composers_composer_id" ON "tune_composers" ("composer_id");

CREATE TABLE "recommended_tunes" (
    -- [sqlgg] module=Sql_types.Dance_id_conv
    "dance_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_recommended_tunes_dance_id_tune_id" UNIQUE ("dance_id", "tune_id"),
    CONSTRAINT "fk_recommended_tunes_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dances" ("id"),
    CONSTRAINT "fk_recommended_tunes_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tunes" ("id")
);

CREATE INDEX "idx_recommended_tunes_tune_id" ON "recommended_tunes" ("tune_id");

CREATE TABLE "versions" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Tune_id_conv
    "tune_id" VARCHAR(14) NOT NULL,
    "key" VARCHAR(32) NOT NULL,
    "remark" VARCHAR,
    "disambiguation" VARCHAR,
    "monolithic_lilypond" TEXT,
    "monolithic_bars" INT,
    "monolithic_or_default_structure" VARCHAR(32),
    "destructured_as_2_4" BOOLEAN NOT NULL,
    CONSTRAINT "pk_versions" PRIMARY KEY ("id"),
    CONSTRAINT "fk_versions_id" FOREIGN KEY ("id") REFERENCES "entities" ("id"),
    CONSTRAINT "fk_versions_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tunes" ("id")
);

CREATE INDEX "idx_versions_tune_id" ON "versions" ("tune_id");

CREATE TABLE "version_arrangers" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "arranger_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_version_arrangers_version_id_arranger_id" UNIQUE ("version_id", "arranger_id"),
    CONSTRAINT "fk_version_arrangers_version_id" FOREIGN KEY ("version_id") REFERENCES "versions" ("id"),
    CONSTRAINT "fk_version_arrangers_arranger_id" FOREIGN KEY ("arranger_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_version_arrangers_arranger_id" ON "version_arrangers" ("arranger_id");

CREATE TABLE "version_sources" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Source_id_conv
    "source_id" VARCHAR(14) NOT NULL,
    "structure" VARCHAR(32) NOT NULL,
    "details" VARCHAR,
    CONSTRAINT "uq_version_sources_version_id_source_id_structure" UNIQUE ("version_id", "source_id" ,"structure"),
    CONSTRAINT "fk_version_sources_version_id" FOREIGN KEY ("version_id") REFERENCES "versions" ("id"),
    CONSTRAINT "fk_version_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "sources" ("id")
);

CREATE INDEX "idx_version_sources_source_id" ON "version_sources" ("source_id");

CREATE TABLE "version_destructured_parts" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    "part" VARCHAR(32) NOT NULL,
    "melody" VARCHAR NOT NULL,
    "chords" VARCHAR NOT NULL,
    CONSTRAINT "uq_version_destructured_parts_version_id_part" UNIQUE ("version_id", "part"),
    CONSTRAINT "fk_version_destructured_parts_version_id" FOREIGN KEY ("version_id") REFERENCES "versions" ("id")
);

CREATE TABLE "version_destructured_transitions" (
    -- [sqlgg] module=Sql_types.Version_id_conv
    "version_id" VARCHAR(14) NOT NULL,
    "from_parts" VARCHAR(32) NOT NULL,
    "to_parts" VARCHAR(32) NOT NULL,
    "melody" VARCHAR NOT NULL,
    "chords" VARCHAR NOT NULL,
    CONSTRAINT "uq_version_destructured_transitions_version_id_from_parts_to_parts" UNIQUE ("version_id", "from_parts", "to_parts"),
    CONSTRAINT "fk_version_destructured_transitions_version_id" FOREIGN KEY ("version_id") REFERENCES "versions" ("id")
);

CREATE TABLE "sets" (
    -- [sqlgg] module=Sql_types.Set_id_conv
    "id" VARCHAR(14) NOT NULL,
    "name" VARCHAR NOT NULL,
    "kind" VARCHAR NOT NULL,
    "order" VARCHAR NOT NULL,
    "remark" VARCHAR,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "pk_sets" PRIMARY KEY ("id"),
    CONSTRAINT "fk_sets_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_sets_name" ON "sets" USING GIN ("name" "public"."gin_trgm_ops");
CREATE INDEX "idx_sets_name_search" ON "sets" USING GIN ("name_search" "public"."gin_trgm_ops");

CREATE TABLE "set_conceptors" (
    -- [sqlgg] module=Sql_types.Set_id_conv
    "set_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "conceptor_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_set_conceptors_set_id_conceptor_id" UNIQUE ("set_id", "conceptor_id"),
    CONSTRAINT "fk_set_conceptors_set_id" FOREIGN KEY ("set_id") REFERENCES "sets" ("id"),
    CONSTRAINT "fk_set_conceptors_conceptor_id" FOREIGN KEY ("conceptor_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_set_conceptors_conceptor_id" ON "set_conceptors" ("conceptor_id");

CREATE TABLE "set_content_items" (
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
    CONSTRAINT "uq_set_content_items_set_id_index" UNIQUE ("set_id", "index"),
    CONSTRAINT "fk_set_content_items_set_id" FOREIGN KEY ("set_id") REFERENCES "sets" ("id"),
    CONSTRAINT "fk_set_content_items_version_id" FOREIGN KEY ("version_id") REFERENCES "versions" ("id")
);

CREATE INDEX "idx_set_content_items_version_id" ON "set_content_items" ("version_id");

CREATE TABLE "books" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "id" VARCHAR(14) NOT NULL,
    "name" VARCHAR NOT NULL,
    "date" VARCHAR,
    "remark" VARCHAR,
    "scddb_id" INT,
    "name_search" TEXT GENERATED ALWAYS AS (make_name_search("name")) STORED,
    CONSTRAINT "pk_books" PRIMARY KEY ("id"),
    CONSTRAINT "fk_books_id" FOREIGN KEY ("id") REFERENCES "entities" ("id")
);

CREATE INDEX "idx_books_name" ON "books" USING GIN ("name" "public"."gin_trgm_ops");
CREATE INDEX "idx_books_name_search" ON "books" USING GIN ("name_search" "public"."gin_trgm_ops");

CREATE TABLE "book_authors" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "book_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Person_id_conv
    "author_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_book_authors_book_id_author_id" UNIQUE ("book_id", "author_id"),
    CONSTRAINT "fk_book_authors_book_id" FOREIGN KEY ("book_id") REFERENCES "books" ("id"),
    CONSTRAINT "fk_book_authors_author_id" FOREIGN KEY ("author_id") REFERENCES "persons" ("id")
);

CREATE INDEX "idx_book_authors_author_id" ON "book_authors" ("author_id");

CREATE TABLE "book_sources" (
    -- [sqlgg] module=Sql_types.Book_id_conv
    "book_id" VARCHAR(14) NOT NULL,
    -- [sqlgg] module=Sql_types.Source_id_conv
    "source_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "uq_book_sources_book_id_source_id" UNIQUE ("book_id", "source_id"),
    CONSTRAINT "fk_book_sources_book_id" FOREIGN KEY ("book_id") REFERENCES "books" ("id"),
    CONSTRAINT "fk_book_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "sources" ("id")
);

CREATE INDEX "idx_book_sources_source_id" ON "book_sources" ("source_id");

CREATE TYPE "page_type" AS ENUM ('Part', 'Dance_only', 'Dance_versions', 'Dance_set', 'Versions', 'Set');

CREATE TABLE "book_content_pages" (
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
    CONSTRAINT "uq_book_content_pages_book_id_index" UNIQUE ("book_id", "index"),
    CONSTRAINT "fk_book_content_pages_book_id" FOREIGN KEY ("book_id") REFERENCES "books" ("id"),
    CONSTRAINT "fk_book_content_pages_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dances" ("id"),
    CONSTRAINT "fk_book_content_pages_set_id" FOREIGN KEY ("set_id") REFERENCES "sets" ("id")
);

CREATE INDEX "idx_book_content_pages_dance_id" ON "book_content_pages" ("dance_id");
CREATE INDEX "idx_book_content_pages_set_id" ON "book_content_pages" ("set_id");

CREATE TABLE "book_content_page_versions" ( -- standalone or within dance
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
    CONSTRAINT "uq_book_content_page_versions_book_id_content_index_index" UNIQUE ("book_id", "content_index", "index"),
    CONSTRAINT "fk_book_content_page_versions_book_id" FOREIGN KEY ("book_id") REFERENCES "books" ("id"),
    CONSTRAINT "fk_book_content_page_versions_version_id" FOREIGN KEY ("version_id") REFERENCES "versions" ("id")
);

CREATE INDEX "idx_book_content_page_versions_version_id" ON "book_content_page_versions" ("version_id");
