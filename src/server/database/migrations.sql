-- -------------------------------------------------------------------------- --
-- Administrative stuff to support automated migrations
-- -------------------------------------------------------------------------- --

-- @create_table_migrations
CREATE TABLE IF NOT EXISTS "migrations" (
    "name" VARCHAR(255) PRIMARY KEY,
    "applied_at" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- @get_migration
SELECT "applied_at" FROM "migrations"
WHERE "name" = @name;

-- @register_migration
INSERT INTO "migrations" ("name") VALUES (@name);

-- -------------------------------------------------------------------------- --
-- First migrations: creation of basic id->json tables
-- -------------------------------------------------------------------------- --

-- @m001_2026_04_add_book_table
CREATE TABLE "book" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m002_2026_04_add_dance_table
CREATE TABLE "dance" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m003_2026_04_add_person_table
CREATE TABLE "person" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m004_2026_04_add_set_table
CREATE TABLE "set" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m005_2026_04_add_source_table
CREATE TABLE "source" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL,
    "cover" BYTEA
);

-- @m006_2026_04_add_tune_table
CREATE TABLE "tune" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m007_2026_04_add_user_table
CREATE TABLE "user" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m008_2026_04_add_version_table
CREATE TABLE "version" (
    "id" VARCHAR(14) PRIMARY KEY,
    "json" JSON NOT NULL
);

-- @m009_2026_04_add_globally_unique_id_table
CREATE TABLE "globally_unique_id" (
    "id" VARCHAR(14) PRIMARY KEY,
    "type" TEXT NOT NULL
);

-- @m010_2026_04_insert_ids_from_book_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Book' AS "type"
FROM "book";

-- @m011_2026_04_add_fk_book_id_key
ALTER TABLE "book"
ADD CONSTRAINT "fk_book_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m012_2026_04_insert_ids_from_dance_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Dance' AS "type"
FROM "dance";

-- @m013_2026_04_add_fk_dance_id_key
ALTER TABLE "dance"
ADD CONSTRAINT "fk_dance_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m014_2026_04_insert_ids_from_person_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Person' AS "type"
FROM "person";

-- @m015_2026_04_add_fk_person_id_key
ALTER TABLE "person"
ADD CONSTRAINT "fk_person_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m016_2026_04_insert_ids_from_set_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Set' AS "type"
FROM "set";

-- @m017_2026_04_add_fk_set_id_key
ALTER TABLE "set"
ADD CONSTRAINT "fk_set_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m018_2026_04_insert_ids_from_source_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Source' AS "type"
FROM "source";

-- @m019_2026_04_add_fk_source_id_key
ALTER TABLE "source"
ADD CONSTRAINT "fk_source_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m020_2026_04_insert_ids_from_tune_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Tune' AS "type"
FROM "tune";

-- @m021_2026_04_add_fk_tune_id_key
ALTER TABLE "tune"
ADD CONSTRAINT "fk_tune_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m022_2026_04_insert_ids_from_user_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'User' AS "type"
FROM "user";

-- @m023_2026_04_add_fk_user_id_key
ALTER TABLE "user"
ADD CONSTRAINT "fk_user_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m024_2026_04_insert_ids_from_version_into_globally_unique_id
INSERT INTO "globally_unique_id"
SELECT
    "id",
    'Version' AS "type"
FROM "version";

-- @m025_2026_04_add_fk_version_id_key
ALTER TABLE "version"
ADD CONSTRAINT "fk_version_id"
FOREIGN KEY ("id") REFERENCES "globally_unique_id" ("id");

-- @m026_2026_04_split_user_json_into_fields__add_columns
ALTER TABLE "user"
ADD COLUMN "username" VARCHAR(256),
ADD COLUMN "password" VARCHAR(256),
ADD COLUMN "password_reset_token_hash" VARCHAR(256),
ADD COLUMN "password_reset_token_max_date" TIMESTAMP,
ADD COLUMN "role" JSON,
ADD COLUMN "remember_me_tokens" JSON,
ADD COLUMN "created_at" TIMESTAMP,
ADD COLUMN "modified_at" TIMESTAMP;

-- @m026_2026_04_split_user_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "user";

-- @m026_2026_04_split_user_json_into_fields__update_one
UPDATE "user"
SET
    "username" = @username,
    "password" = @password,
    "password_reset_token_hash" = @password_reset_token_hash,
    "password_reset_token_max_date" = @password_reset_token_max_date,
    "remember_me_tokens" = @remember_me_tokens,
    "role" = @role,
    "created_at" = @created_at,
    "modified_at" = @modified_at
WHERE "id" = @id;

-- @m026_2026_04_split_user_json_into_fields__set_not_null
ALTER TABLE "user"
  ALTER COLUMN "username" SET NOT NULL,
  ALTER COLUMN "role" SET NOT NULL,
  ALTER COLUMN "remember_me_tokens" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  ADD UNIQUE ("username");


-- @m026_2026_04_split_user_json_into_fields__drop_json_column
ALTER TABLE "user"
DROP COLUMN "json";

-- @m027_2026_04_split_role_json_into_fields__add_columns
ALTER TABLE "user"
ADD COLUMN "role_new" SMALLINT,
ADD COLUMN "omniscience" BOOLEAN;

-- @m027_2026_04_split_role_json_into_fields__get_all
SELECT
    "id",
    "role"
FROM "user";

-- @m027_2026_04_split_role_json_into_fields__update_one
UPDATE "user"
SET
    "role_new" = @role_new,
    "omniscience" = @omniscience
WHERE id = @id;

-- @m027_2026_04_split_role_json_into_fields__cleanup_columns_1
ALTER TABLE "user"
  DROP COLUMN "role",
  ALTER COLUMN "role_new" TYPE SMALLINT,
  ALTER COLUMN "role_new" SET NOT NULL,
  ALTER COLUMN "omniscience" TYPE BOOLEAN,
  ALTER COLUMN "omniscience" SET NOT NULL;

-- @m027_2026_04_split_role_json_into_fields__cleanup_columns_2
ALTER TABLE "user"
  RENAME COLUMN "role_new" TO "role";

-- @m028_2026_04_add_remember_me_tokens_table
CREATE TABLE "remember_me_tokens" (
    "user_id" VARCHAR(14) NOT NULL,
    "key" VARCHAR(256) NOT NULL,
    "hash" VARCHAR(256) NOT NULL,
    "max_date" TIMESTAMP NOT NULL,
    CONSTRAINT "fk_user_id" FOREIGN KEY ("user_id") REFERENCES "user" ("id")
);

-- @m029_2026_04_drop_remember_me_tokens_column
ALTER TABLE "user"
DROP COLUMN "remember_me_tokens";

-- @m030_2026_05_split_person_json_into_fields__add_columns
ALTER TABLE "person"
ADD COLUMN "name" VARCHAR(256),
ADD COLUMN "scddb_id" INT,
ADD COLUMN "composed_tunes_are_public" BOOLEAN,
ADD COLUMN "published_tunes_are_public" BOOLEAN,
ADD COLUMN "created_at" TIMESTAMP,
ADD COLUMN "modified_at" TIMESTAMP;

-- @m030_2026_05_split_person_json_into_fields__add_column_to_user
ALTER TABLE "user"
ADD COLUMN "person_id" VARCHAR(14);

-- @m030_2026_05_split_person_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "person";

-- @m030_2026_05_split_person_json_into_fields__update_one
UPDATE "person"
SET
    "name" = @name,
    "scddb_id" = @scddb_id,
    "composed_tunes_are_public" = @composed_tunes_are_public,
    "published_tunes_are_public" = @published_tunes_are_public,
    "created_at" = @created_at,
    "modified_at" = @modified_at
WHERE "id" = @id;

-- @m030_2026_05_split_person_json_into_fields__update_user
UPDATE "user"
SET
    "person_id" = @person_id
WHERE "id" = @id;

-- @m030_2026_05_split_person_json_into_fields__cleanup_columns
ALTER TABLE "person"
  ALTER COLUMN "name" SET NOT NULL,
  ALTER COLUMN "composed_tunes_are_public" SET NOT NULL,
  ALTER COLUMN "published_tunes_are_public" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  DROP COLUMN "json";

-- @m030_2026_05_split_person_json_into_fields__add_constraint
ALTER TABLE "user"
ADD CONSTRAINT "fk_user_person_id" FOREIGN KEY ("person_id") REFERENCES "person" ("id");

-- @m031_2026_05_split_source_json_into_fields__add_columns
ALTER TABLE "source"
ADD COLUMN "name" VARCHAR(256),
ADD COLUMN "short_name" VARCHAR(64),
ADD COLUMN "scddb_id" INT,
ADD COLUMN "description" TEXT,
ADD COLUMN "date" VARCHAR(32),
ADD COLUMN "created_at" TIMESTAMP,
ADD COLUMN "modified_at" TIMESTAMP;

-- @m031_2026_05_split_source_json_into_fields__add_source_editors_table
CREATE TABLE "source_editors" (
    "source_id" VARCHAR(14) NOT NULL,
    "person_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_source_editors_source_id" FOREIGN KEY ("source_id") REFERENCES "source" ("id"),
    CONSTRAINT "fk_source_editors_person_id" FOREIGN KEY ("person_id") REFERENCES "person" ("id")
);

-- @m031_2026_05_split_source_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "source";

-- @m031_2026_05_split_source_json_into_fields__update_one
UPDATE "source"
SET
    "name" = @name,
    "short_name" = @short_name,
    "scddb_id" = @scddb_id,
    "description" = @description,
    "date" = @date,
    "created_at" = @created_at,
    "modified_at" = @modified_at
WHERE "id" = @id;

-- @m031_2026_05_split_source_json_into_fields__add_one_editor
INSERT INTO "source_editors" (
    "source_id",
    "person_id"
) VALUES (
    @source_id,
    @person_id
);

-- @m031_2026_05_split_source_json_into_fields__cleanup_columns
ALTER TABLE "source"
  ALTER COLUMN "name" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  DROP COLUMN "json";

-- @m032_2026_05_split_dance_json_into_fields__add_columns
ALTER TABLE "dance"
  ADD COLUMN "name" VARCHAR(256),
  ADD COLUMN "kind" VARCHAR(32),
  ADD COLUMN "two_chords" SMALLINT,
  ADD COLUMN "scddb_id" INT,
  ADD COLUMN "disambiguation" VARCHAR(256),
  ADD COLUMN "date" VARCHAR(32),
  ADD COLUMN "created_at" TIMESTAMP,
  ADD COLUMN "modified_at" TIMESTAMP;

-- @m032_2026_05_split_dance_json_into_fields__add_dance_extra_names_table
CREATE TABLE "dance_extra_names" (
    "dance_id" VARCHAR(14) NOT NULL,
    "extra_name" VARCHAR(256) NOT NULL,
    CONSTRAINT "fk_dance_extra_names_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id")
);

-- @m032_2026_05_split_dance_json_into_fields__add_dance_devisers_table
CREATE TABLE "dance_devisers" (
    "dance_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    "deviser_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_dance_devisers_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id"),
    CONSTRAINT "fk_dance_devisers_deviser_id" FOREIGN KEY ("deviser_id") REFERENCES "person" ("id")
);

-- @m032_2026_05_split_dance_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "dance";

-- @m032_2026_05_split_dance_json_into_fields__update_one
UPDATE "dance"
SET
    "name" = @name,
    "kind" = @kind,
    "two_chords" = @two_chords,
    "scddb_id" = @scddb_id,
    "disambiguation" = @disambiguation,
    "date" = @date,
    "created_at" = @created_at,
    "modified_at" = @modified_at
WHERE "id" = @id;

-- @m032_2026_05_split_dance_json_into_fields__add_one_extra_name
INSERT INTO "dance_extra_names" (
    "dance_id",
    "extra_name"
) VALUES (
    @dance_id,
    @extra_name
);

-- @m032_2026_05_split_dance_json_into_fields__add_one_deviser
INSERT INTO "dance_devisers" (
    "dance_id",
    "index",
    "deviser_id"
) VALUES (
    @dance_id,
    @index,
    @deviser_id
);

-- @m032_2026_05_split_dance_json_into_fields__cleanup_columns
ALTER TABLE "dance"
  ALTER COLUMN "name" SET NOT NULL,
  ALTER COLUMN "kind" SET NOT NULL,
  ALTER COLUMN "two_chords" SET NOT NULL,
  ALTER COLUMN "disambiguation" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  DROP COLUMN "json";

-- @m033_2026_05_split_tune_json_into_fields__add_columns
ALTER TABLE "tune"
  ADD COLUMN "name" VARCHAR,
  ADD COLUMN "kind" VARCHAR(32),
  ADD COLUMN "remark" VARCHAR,
  ADD COLUMN "scddb_id" INT,
  ADD COLUMN "date" VARCHAR(32),
  ADD COLUMN "created_at" TIMESTAMP,
  ADD COLUMN "modified_at" TIMESTAMP;

-- @m033_2026_05_split_tune_json_into_fields__add_tune_extra_names_table
CREATE TABLE "tune_extra_names" (
    "tune_id" VARCHAR(14) NOT NULL,
    "extra_name" VARCHAR NOT NULL,
    CONSTRAINT "fk_tune_extra_names_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id")
);

-- @m033_2026_05_split_tune_json_into_fields__add_tune_composers_table
CREATE TABLE "tune_composers" (
    "tune_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    "composer_id" VARCHAR(14) NOT NULL,
    "details" VARCHAR NOT NULL,
    CONSTRAINT "fk_tune_composers_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id"),
    CONSTRAINT "fk_tune_composers_composer_id" FOREIGN KEY ("composer_id") REFERENCES "person" ("id")
);

-- @m033_2026_05_split_tune_json_into_fields__add_recommended_tunes_table
CREATE TABLE "recommended_tunes" (
    "dance_id" VARCHAR(14) NOT NULL,
    "tune_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_recommended_tunes_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id"),
    CONSTRAINT "fk_recommended_tunes_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id")
);

-- @m033_2026_05_split_tune_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "tune";

-- @m033_2026_05_split_tune_json_into_fields__update_one
UPDATE "tune"
SET
    "name" = @name,
    "kind" = @kind,
    "remark" = @remark,
    "scddb_id" = @scddb_id,
    "date" = @date,
    "created_at" = @created_at,
    "modified_at" = @modified_at
WHERE "id" = @id;

-- @m033_2026_05_split_tune_json_into_fields__add_one_extra_name
INSERT INTO "tune_extra_names" (
    "tune_id",
    "extra_name"
) VALUES (
    @tune_id,
    @extra_name
);

-- @m033_2026_05_split_tune_json_into_fields__add_one_composer
INSERT INTO "tune_composers" (
    "tune_id",
    "index",
    "composer_id",
    "details"
) VALUES (
    @tune_id,
    @index,
    @composer_id,
    @details
);

-- @m033_2026_05_split_tune_json_into_fields__add_one_recommended_tune
INSERT INTO "recommended_tunes" (
    "dance_id",
    "tune_id"
) VALUES (
    @dance_id,
    @tune_id
);

-- @m033_2026_05_split_tune_json_into_fields__cleanup_columns
ALTER TABLE "tune"
  ALTER COLUMN "name" SET NOT NULL,
  ALTER COLUMN "kind" SET NOT NULL,
  ALTER COLUMN "remark" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  DROP COLUMN "json";

-- @m034_2026_05_split_version_json_into_fields__add_columns
ALTER TABLE "version"
  ADD COLUMN "tune_id" VARCHAR(14),
  ADD COLUMN "key" VARCHAR(32),
  ADD COLUMN "remark" VARCHAR,
  ADD COLUMN "disambiguation" VARCHAR,
  ADD COLUMN "monolithic_lilypond" TEXT,
  ADD COLUMN "monolithic_bars" INT,
  ADD COLUMN "monolithic_or_default_structure" VARCHAR(32),
  ADD COLUMN "created_at" TIMESTAMP,
  ADD COLUMN "modified_at" TIMESTAMP;

-- @m034_2026_05_split_version_json_into_fields__add_version_arrangers_table
CREATE TABLE "version_arrangers" (
    "version_id" VARCHAR(14) NOT NULL,
    "arranger_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_version_arrangers_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "fk_version_arrangers_arranger_id" FOREIGN KEY ("arranger_id") REFERENCES "person" ("id")
);

-- @m034_2026_05_split_version_json_into_fields__add_version_sources_table
CREATE TABLE "version_sources" (
    "version_id" VARCHAR(14) NOT NULL,
    "source_id" VARCHAR(14) NOT NULL,
    "structure" VARCHAR(32) NOT NULL,
    "details" VARCHAR NOT NULL,
    CONSTRAINT "fk_version_sources_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id"),
    CONSTRAINT "fk_version_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "source" ("id")
);

-- @m034_2026_05_split_version_json_into_fields__add_version_destructured_parts_table
CREATE TABLE "version_destructured_parts" (
    "version_id" VARCHAR(14) NOT NULL,
    "part" VARCHAR(32) NOT NULL,
    "melody" VARCHAR NOT NULL,
    "chords" VARCHAR NOT NULL,
    CONSTRAINT "fk_version_destructured_parts_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id")
);

-- @m034_2026_05_split_version_json_into_fields__add_version_destructured_transitions_table
CREATE TABLE "version_destructured_transitions" (
    "version_id" VARCHAR(14) NOT NULL,
    "from_parts" VARCHAR(32) NOT NULL,
    "to_parts" VARCHAR(32) NOT NULL,
    "melody" VARCHAR NOT NULL,
    "chords" VARCHAR NOT NULL,
    CONSTRAINT "fk_version_destructured_transitions_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id")
);

-- @m034_2026_05_split_version_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "version";

-- @m034_2026_05_split_version_json_into_fields__update_one
UPDATE "version"
SET
    "tune_id" = @tune_id,
    "key" = @key,
    "remark" = @remark,
    "disambiguation" = @disambiguation,
    "monolithic_lilypond" = @monolithic_lilypond,
    "monolithic_bars" = @monolithic_bars,
    "monolithic_or_default_structure" = @monolithic_or_default_structure,
    "created_at" = @created_at,
    "modified_at" = @modified_at
WHERE "id" = @id;

-- @m034_2026_05_split_version_json_into_fields__add_one_arranger
INSERT INTO "version_arrangers" (
    "version_id",
    "arranger_id"
) VALUES (
    @version_id,
    @arranger_id
);

-- @m034_2026_05_split_version_json_into_fields__add_one_source
INSERT INTO "version_sources" (
    "version_id",
    "source_id",
    "structure",
    "details"
) VALUES (
    @version_id,
    @source_id,
    @structure,
    @details
);

-- @m034_2026_05_split_version_json_into_fields__add_one_destructured_part
INSERT INTO "version_destructured_parts" (
    "version_id",
    "part",
    "melody",
    "chords"
) VALUES (
    @version_id,
    @part,
    @melody,
    @chords
);

-- @m034_2026_05_split_version_json_into_fields__add_one_destructured_transition
INSERT INTO "version_destructured_transitions" (
    "version_id",
    "from_parts",
    "to_parts",
    "melody",
    "chords"
) VALUES (
    @version_id,
    @from_parts,
    @to_parts,
    @melody,
    @chords
);

-- @m034_2026_05_split_version_json_into_fields__cleanup_columns
ALTER TABLE "version"
  ALTER COLUMN "tune_id" SET NOT NULL,
  ALTER COLUMN "key" SET NOT NULL,
  ALTER COLUMN "remark" SET NOT NULL,
  ALTER COLUMN "disambiguation" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  ADD CONSTRAINT "fk_version_tune_id" FOREIGN KEY ("tune_id") REFERENCES "tune" ("id"),
  DROP COLUMN "json";

-- @m035_2026_05_split_set_json_into_fields__add_columns
ALTER TABLE "set"
  ADD COLUMN "name" VARCHAR,
  ADD COLUMN "kind" VARCHAR,
  ADD COLUMN "order" VARCHAR,
  ADD COLUMN "instructions" VARCHAR,
  ADD COLUMN "remark" VARCHAR,
  ADD COLUMN "created_at" TIMESTAMP,
  ADD COLUMN "modified_at" TIMESTAMP,
  ADD COLUMN "visibility" INT;

-- @m035_2026_05_split_set_json_into_fields__add_conceptors_table
CREATE TABLE "set_conceptors" (
    "set_id" VARCHAR(14) NOT NULL,
    "conceptor_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_set_conceptors_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_conceptors_conceptor_id" FOREIGN KEY ("conceptor_id") REFERENCES "person" ("id")
);

-- @m035_2026_05_split_set_json_into_fields__add_dances_table
CREATE TABLE "set_dances" (
    "set_id" VARCHAR(14) NOT NULL,
    "dance_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_set_dances_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_dances_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id")
);

-- @m035_2026_05_split_set_json_into_fields__add_content_table
CREATE TABLE "set_content" (
    "set_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    "version_id" VARCHAR(14) NOT NULL,
    "version_parameter_transposition_semitones" INT,
    "version_parameter_first_bar" INT,
    "version_parameter_clef" VARCHAR,
    "version_parameter_structure" VARCHAR,
    "version_parameter_trivia" VARCHAR,
    "version_parameter_display_name" VARCHAR,
    "version_parameter_display_composer" VARCHAR,
    CONSTRAINT "fk_set_content_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_content_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id")
);

-- @m035_2026_05_split_set_json_into_fields__add_viewers_table
CREATE TABLE "set_viewers" (
    "set_id" VARCHAR(14) NOT NULL,
    "viewer_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_set_viewers_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_viewers_viewer_id" FOREIGN KEY ("viewer_id") REFERENCES "user" ("id")
);

-- @m035_2026_05_split_set_json_into_fields__add_owners_table
CREATE TABLE "set_owners" (
    "set_id" VARCHAR(14) NOT NULL,
    "owner_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_set_owners_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id"),
    CONSTRAINT "fk_set_owners_owner_id" FOREIGN KEY ("owner_id") REFERENCES "user" ("id")
);

-- @m035_2026_05_split_set_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "set";

-- @m035_2026_05_split_set_json_into_fields__update_one
UPDATE "set"
SET
    "name" = @name,
    "kind" = @kind,
    "order" = @order,
    "instructions" = @instructions,
    "remark" = @remark,
    "created_at" = @created_at,
    "modified_at" = @modified_at,
    "visibility" = @visibility
WHERE "id" = @id;

-- @m035_2026_05_split_set_json_into_fields__add_one_conceptor
INSERT INTO "set_conceptors" (
    "set_id",
    "conceptor_id"
) VALUES (
    @set_id,
    @conceptor_id
);

-- @m035_2026_05_split_set_json_into_fields__add_one_dance
INSERT INTO "set_dances" (
    "set_id",
    "dance_id"
) VALUES (
    @set_id,
    @dance_id
);

-- @m035_2026_05_split_set_json_into_fields__add_one_content_item
INSERT INTO "set_content" (
    "set_id",
    "index",
    "version_id",
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
) VALUES (
    @set_id,
    @index,
    @version_id,
    @version_parameter_transposition_semitones,
    @version_parameter_first_bar,
    @version_parameter_clef,
    @version_parameter_structure,
    @version_parameter_trivia,
    @version_parameter_display_name,
    @version_parameter_display_composer
);

-- @m035_2026_05_split_set_json_into_fields__add_one_viewer
INSERT INTO "set_viewers" (
    "set_id",
    "viewer_id"
) VALUES (
    @set_id,
    @viewer_id
);

-- @m035_2026_05_split_set_json_into_fields__add_one_owner
INSERT INTO "set_owners" (
    "set_id",
    "owner_id"
) VALUES (
    @set_id,
    @owner_id
);

-- @m035_2026_05_split_set_json_into_fields__cleanup_columns
ALTER TABLE "set"
  ALTER COLUMN "name" SET NOT NULL,
  ALTER COLUMN "kind" SET NOT NULL,
  ALTER COLUMN "order" SET NOT NULL,
  ALTER COLUMN "instructions" SET NOT NULL,
  ALTER COLUMN "remark" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  ALTER COLUMN "visibility" SET NOT NULL,
  DROP COLUMN "json";

-- @m036_2026_05_split_book_json_into_fields__add_columns
ALTER TABLE "book"
  ADD COLUMN "title" VARCHAR,
  ADD COLUMN "date" VARCHAR,
  ADD COLUMN "remark" VARCHAR,
  ADD COLUMN "scddb_id" INT,
  ADD COLUMN "created_at" TIMESTAMP,
  ADD COLUMN "modified_at" TIMESTAMP,
  ADD COLUMN "visibility" INT;

-- @m036_2026_05_split_book_json_into_fields__add_authors_table
CREATE TABLE "book_authors" (
    "book_id" VARCHAR(14) NOT NULL,
    "author_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_book_authors_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_authors_author_id" FOREIGN KEY ("author_id") REFERENCES "person" ("id")
);

-- @m036_2026_05_split_book_json_into_fields__add_sources_table
CREATE TABLE "book_sources" (
    "book_id" VARCHAR(14) NOT NULL,
    "source_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_book_sources_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_sources_source_id" FOREIGN KEY ("source_id") REFERENCES "source" ("id")
);

-- @m036_2026_05_split_book_json_into_fields__add_content_table
CREATE TABLE "book_content" (
    "book_id" VARCHAR(14) NOT NULL,
    "index" INT NOT NULL,
    "page_type" INT NOT NULL,
    "part_title" VARCHAR,
    "dance_id" VARCHAR(14),
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
    CONSTRAINT "fk_book_content_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_content_dance_id" FOREIGN KEY ("dance_id") REFERENCES "dance" ("id"),
    CONSTRAINT "fk_book_content_set_id" FOREIGN KEY ("set_id") REFERENCES "set" ("id")
);

-- @m036_2026_05_split_book_json_into_fields__add_content_versions_table
CREATE TABLE "book_content_versions" (
    "book_id" VARCHAR(14) NOT NULL,
    "content_index" INT NOT NULL,
    "index" INT NOT NULL,
    "version_id" VARCHAR(14) NOT NULL,
    "version_parameter_transposition_semitones" INT,
    "version_parameter_first_bar" INT,
    "version_parameter_clef" VARCHAR,
    "version_parameter_structure" VARCHAR,
    "version_parameter_trivia" VARCHAR,
    "version_parameter_display_name" VARCHAR,
    "version_parameter_display_composer" VARCHAR,
    CONSTRAINT "fk_book_content_versions_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_content_versions_version_id" FOREIGN KEY ("version_id") REFERENCES "version" ("id")
);

-- @m036_2026_05_split_book_json_into_fields__add_viewers_table
CREATE TABLE "book_viewers" (
    "book_id" VARCHAR(14) NOT NULL,
    "viewer_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_book_viewers_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_viewers_viewer_id" FOREIGN KEY ("viewer_id") REFERENCES "user" ("id")
);

-- @m036_2026_05_split_book_json_into_fields__add_owners_table
CREATE TABLE "book_owners" (
    "book_id" VARCHAR(14) NOT NULL,
    "owner_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_book_owners_book_id" FOREIGN KEY ("book_id") REFERENCES "book" ("id"),
    CONSTRAINT "fk_book_owners_owner_id" FOREIGN KEY ("owner_id") REFERENCES "user" ("id")
);

-- @m036_2026_05_split_book_json_into_fields__get_all
SELECT
    "id",
    "json"
FROM "book";

-- @m036_2026_05_split_book_json_into_fields__update_one
UPDATE "book"
SET
    "title" = @title,
    "date" = @date,
    "remark" = @remark,
    "scddb_id" = @scddb_id,
    "created_at" = @created_at,
    "modified_at" = @modified_at,
    "visibility" = @visibility
WHERE "id" = @id;

-- @m036_2026_05_split_book_json_into_fields__add_one_author
INSERT INTO "book_authors" (
    "book_id",
    "author_id"
) VALUES (
    @book_id,
    @author_id
);

-- @m036_2026_05_split_book_json_into_fields__add_one_source
INSERT INTO "book_sources" (
    "book_id",
    "source_id"
) VALUES (
    @book_id,
    @source_id
);

-- @m036_2026_05_split_book_json_into_fields__add_one_content_item
INSERT INTO "book_content" (
    "book_id",
    "index",
    "page_type",
    "part_title",
    "dance_id",
    "set_id",
    "set_parameter_display_name",
    "set_parameter_display_conceptor",
    "set_parameter_display_kind",
    "set_parameter_version_parameter_transposition_semitones",
    "set_parameter_version_parameter_first_bar",
    "set_parameter_version_parameter_clef",
    "set_parameter_version_parameter_structure",
    "set_parameter_version_parameter_trivia",
    "set_parameter_version_parameter_display_name",
    "set_parameter_version_parameter_display_composer"
) VALUES (
    @book_id,
    @index,
    @page_type,
    @part_title,
    @dance_id,
    @set_id,
    @set_parameter_display_name,
    @set_parameter_display_conceptor,
    @set_parameter_display_kind,
    @set_parameter_version_parameter_transposition_semitones,
    @set_parameter_version_parameter_first_bar,
    @set_parameter_version_parameter_clef,
    @set_parameter_version_parameter_structure,
    @set_parameter_version_parameter_trivia,
    @set_parameter_version_parameter_display_name,
    @set_parameter_version_parameter_display_composer
);

-- @m036_2026_05_split_book_json_into_fields__add_one_content_version
INSERT INTO "book_content_versions" (
    "book_id",
    "content_index",
    "index",
    "version_id",
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
) VALUES (
    @book_id,
    @content_index,
    @index,
    @version_id,
    @version_parameter_transposition_semitones,
    @version_parameter_first_bar,
    @version_parameter_clef,
    @version_parameter_structure,
    @version_parameter_trivia,
    @version_parameter_display_name,
    @version_parameter_display_composer
);

-- @m036_2026_05_split_book_json_into_fields__add_one_viewer
INSERT INTO "book_viewers" (
    "book_id",
    "viewer_id"
) VALUES (
    @book_id,
    @viewer_id
);

-- @m036_2026_05_split_book_json_into_fields__add_one_owner
INSERT INTO "book_owners" (
    "book_id",
    "owner_id"
) VALUES (
    @book_id,
    @owner_id
);

-- @m036_2026_05_split_book_json_into_fields__cleanup_columns
ALTER TABLE "book"
  ALTER COLUMN "title" SET NOT NULL,
  ALTER COLUMN "remark" SET NOT NULL,
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL,
  ALTER COLUMN "visibility" SET NOT NULL,
  DROP COLUMN "json";

-- @m037_2026_05_alter_table_set_drop_column_instructions
ALTER TABLE "set"
DROP COLUMN "instructions";

-- @m038_2026_05_drop_table_set_dances
DROP TABLE "set_dances";

-- @m039_2026_05_alter_table_book_rename_column_title_to_name
ALTER TABLE "book"
RENAME COLUMN "title" TO "name";

-- @m040_2026_05_add_unique_constraint_remember_me_tokens_user_id_key
ALTER TABLE "remember_me_tokens"
ADD CONSTRAINT "uq_remember_me_tokens_user_id_key" UNIQUE ("user_id", "key");

-- @m041_2026_05_add_unique_constraint_source_editors_source_id_person_id
ALTER TABLE "source_editors"
ADD CONSTRAINT "uq_source_editors_source_id_person_id" UNIQUE ("source_id", "person_id");

-- @m042_2026_05_add_unique_constraints_dance_devisers
ALTER TABLE "dance_devisers"
ADD CONSTRAINT "uq_dance_devisers_dance_id_deviser_id" UNIQUE ("dance_id", "deviser_id"),
ADD CONSTRAINT "uq_dance_devisers_dance_id_index_deviser_id" UNIQUE ("dance_id", "index", "deviser_id");

-- @m043_2026_05_add_unique_constraints_tune_composers
ALTER TABLE "tune_composers"
ADD CONSTRAINT "uq_tune_composers_tune_id_composer_id" UNIQUE ("tune_id", "composer_id"),
ADD CONSTRAINT "uq_tune_composers_tune_id_index_composer_id" UNIQUE ("tune_id", "index", "composer_id");

-- @m044_2026_05_add_unique_constraint_recommended_tunes_dance_id_tune_id
ALTER TABLE "recommended_tunes"
ADD CONSTRAINT "uq_recommended_tunes_dance_id_tune_id" UNIQUE ("dance_id", "tune_id");

-- @m045_2026_05_add_unique_constraint_version_arrangers_version_id_arranger_id
ALTER TABLE "version_arrangers"
ADD CONSTRAINT "uq_version_arrangers_version_id_arranger_id" UNIQUE ("version_id", "arranger_id");

-- @m046_2026_05_add_unique_constraint_version_sources_version_id_source_id_structure
ALTER TABLE "version_sources"
ADD CONSTRAINT "uq_version_sources_version_id_source_id_structure" UNIQUE ("version_id", "source_id", "structure");

-- @m047_2026_05_add_unique_constraint_version_destructured_parts_version_id_part
ALTER TABLE "version_destructured_parts"
ADD CONSTRAINT "uq_version_destructured_parts_version_id_part" UNIQUE ("version_id", "part");

-- @m048_2026_05_add_unique_constraint_version_destructured_transitions_version_id_from_parts_to_parts
ALTER TABLE "version_destructured_transitions"
ADD CONSTRAINT "uq_version_destructured_transitions_version_id_from_parts_to_parts" UNIQUE ("version_id", "from_parts", "to_parts");

-- @m049_2026_05_add_unique_constraint_set_conceptors_set_id_conceptor_id
ALTER TABLE "set_conceptors"
ADD CONSTRAINT "uq_set_conceptors_set_id_conceptor_id" UNIQUE ("set_id", "conceptor_id");

-- @m050_2026_05_add_unique_constraint_set_content_set_id_index
ALTER TABLE "set_content"
ADD CONSTRAINT "uq_set_content_set_id_index" UNIQUE ("set_id", "index");

-- @m051_2026_05_add_unique_constraint_set_viewers_set_id_viewer_id
ALTER TABLE "set_viewers"
ADD CONSTRAINT "uq_set_viewers_set_id_viewer_id" UNIQUE ("set_id", "viewer_id");

-- @m052_2026_05_add_unique_constraint_set_owners_set_id_owner_id
ALTER TABLE "set_owners"
ADD CONSTRAINT "uq_set_owners_set_id_owner_id" UNIQUE ("set_id", "owner_id");

-- @m053_2026_05_add_unique_constraint_book_authors_book_id_author_id
ALTER TABLE "book_authors"
ADD CONSTRAINT "uq_book_authors_book_id_author_id" UNIQUE ("book_id", "author_id");

-- @m054_2026_05_add_unique_constraint_book_sources_book_id_source_id
ALTER TABLE "book_sources"
ADD CONSTRAINT "uq_book_sources_book_id_source_id" UNIQUE ("book_id", "source_id");

-- @m055_2026_05_add_unique_constraint_book_content_book_id_index
ALTER TABLE "book_content"
ADD CONSTRAINT "uq_book_content_book_id_index" UNIQUE ("book_id", "index");

-- @m056_2026_05_add_unique_constraint_book_content_versions_book_id_content_index_index
ALTER TABLE "book_content_versions"
ADD CONSTRAINT "uq_book_content_versions_book_id_content_index_index" UNIQUE ("book_id", "content_index", "index");

-- @m057_2026_05_add_unique_constraint_book_viewers_book_id_viewer_id
ALTER TABLE "book_viewers"
ADD CONSTRAINT "uq_book_viewers_book_id_viewer_id" UNIQUE ("book_id", "viewer_id");

-- @m058_2026_05_add_unique_constraint_book_owners_book_id_owner_id
ALTER TABLE "book_owners"
ADD CONSTRAINT "uq_book_owners_book_id_owner_id" UNIQUE ("book_id", "owner_id");




-- @m059_2026_05_string_to_nestring_option__make_dance_disambiguations_nullable
ALTER TABLE "dance"
ALTER COLUMN "disambiguation" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_dance_disambiguations
UPDATE "dance"
SET "disambiguation" = NULL
WHERE "disambiguation" = '';

-- @m059_2026_05_string_to_nestring_option__make_tune_remarks_nullable
ALTER TABLE "tune"
ALTER COLUMN "remark" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_tune_remarks
UPDATE "tune"
SET "remark" = NULL
WHERE "remark" = '';

-- @m059_2026_05_string_to_nestring_option__make_tune_composers_details_nullable
ALTER TABLE "tune_composers"
ALTER COLUMN "details" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_tune_composers_details
UPDATE "tune_composers"
SET "details" = NULL
WHERE "details" = '';

-- @m059_2026_05_string_to_nestring_option__make_version_remarks_disambiguations_nullable
ALTER TABLE "version"
ALTER COLUMN "remark" DROP NOT NULL,
ALTER COLUMN "disambiguation" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_version_remarks
UPDATE "version"
SET "remark" = NULL
WHERE "remark" = '';

-- @m059_2026_05_string_to_nestring_option__convert_version_disambiguations
UPDATE "version"
SET "disambiguation" = NULL
WHERE "disambiguation" = '';

-- @m059_2026_05_string_to_nestring_option__make_version_sources_details_nullable
ALTER TABLE "version_sources"
ALTER COLUMN "details" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_version_sources_details
UPDATE "version_sources"
SET "details" = NULL
WHERE "details" = '';

-- @m059_2026_05_string_to_nestring_option__make_set_remarks_nullable
ALTER TABLE "set"
ALTER COLUMN "remark" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_set_remarks
UPDATE "set"
SET "remark" = NULL
WHERE "remark" = '';

-- @m059_2026_05_string_to_nestring_option__make_book_remarks_nullable
ALTER TABLE "book"
ALTER COLUMN "remark" DROP NOT NULL;

-- @m059_2026_05_string_to_nestring_option__convert_book_remarks
UPDATE "book"
SET "remark" = NULL
WHERE "remark" = '';

-- -- @m060_2026_06_create_extension_pg_trgm
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- @m061_2026_06_use_enum_for_user_role__create_type_role
CREATE TYPE "role" AS ENUM ('Normal_user', 'Maintainer', 'Administrator');

-- @m061_2026_06_use_enum_for_user_role__add_column_role_new
ALTER TABLE "user" ADD COLUMN "role_new" "role";

-- @m061_2026_06_use_enum_for_user_role__convert_normal_users
UPDATE "user" SET "role_new" = 'Normal_user' WHERE "role" = 0;

-- @m061_2026_06_use_enum_for_user_role__convert_maintainers
UPDATE "user" SET "role_new" = 'Maintainer' WHERE "role" = 1;

-- @m061_2026_06_use_enum_for_user_role__convert_administrators
UPDATE "user" SET "role_new" = 'Administrator' WHERE "role" = 2;

-- @m061_2026_06_use_enum_for_user_role__cleanup_columns_1
ALTER TABLE "user"
  ALTER COLUMN "role_new" SET NOT NULL,
  DROP COLUMN "role";

-- @m061_2026_06_use_enum_for_user_role__cleanup_columns_2
ALTER TABLE "user"
  RENAME COLUMN "role_new" TO "role";

-- @m062_2026_06_use_enum_for_two_chords__create_type_two_chords
CREATE TYPE "two_chords" AS ENUM ('Dont_know', 'One_chord', 'Two_chords');

-- @m062_2026_06_use_enum_for_two_chords__add_column_two_chords_new
ALTER TABLE "dance" ADD COLUMN "two_chords_new" "two_chords";

-- @m062_2026_06_use_enum_for_two_chords__convert_dont_know
UPDATE "dance" SET "two_chords_new" = 'Dont_know' WHERE "two_chords" = 0;

-- @m062_2026_06_use_enum_for_two_chords__convert_one_chord
UPDATE "dance" SET "two_chords_new" = 'One_chord' WHERE "two_chords" = 1;

-- @m062_2026_06_use_enum_for_two_chords__convert_two_chords
UPDATE "dance" SET "two_chords_new" = 'Two_chords' WHERE "two_chords" = 2;

-- @m062_2026_06_use_enum_for_two_chords__cleanup_columns_1
ALTER TABLE "dance"
  ALTER COLUMN "two_chords_new" SET NOT NULL,
  DROP COLUMN "two_chords";

-- @m062_2026_06_use_enum_for_two_chords__cleanup_columns_2
ALTER TABLE "dance"
  RENAME COLUMN "two_chords_new" TO "two_chords";

-- @m063_2026_06_use_enum_for_visibility__create_type_visibility
CREATE TYPE "visibility" AS ENUM ('Owners_only', 'Everyone', 'Select_viewers');

-- @m063_2026_06_use_enum_for_visibility__set_add_column_visibility_new
ALTER TABLE "set" ADD COLUMN "visibility_new" "visibility";

-- @m063_2026_06_use_enum_for_visibility__book_add_column_visibility_new
ALTER TABLE "book" ADD COLUMN "visibility_new" "visibility";

-- @m063_2026_06_use_enum_for_visibility__set_convert_owners_only
UPDATE "set" SET "visibility_new" = 'Owners_only' WHERE "visibility" = 0;

-- @m063_2026_06_use_enum_for_visibility__book_convert_owners_only
UPDATE "book" SET "visibility_new" = 'Owners_only' WHERE "visibility" = 0;

-- @m063_2026_06_use_enum_for_visibility__set_convert_everyone
UPDATE "set" SET "visibility_new" = 'Everyone' WHERE "visibility" = 1;

-- @m063_2026_06_use_enum_for_visibility__book_convert_everyone
UPDATE "book" SET "visibility_new" = 'Everyone' WHERE "visibility" = 1;

-- @m063_2026_06_use_enum_for_visibility__set_convert_select_viewers
UPDATE "set" SET "visibility_new" = 'Select_viewers' WHERE "visibility" = 2;

-- @m063_2026_06_use_enum_for_visibility__book_convert_select_viewers
UPDATE "book" SET "visibility_new" = 'Select_viewers' WHERE "visibility" = 2;

-- @m063_2026_06_use_enum_for_visibility__set_cleanup_columns_1
ALTER TABLE "set"
  ALTER COLUMN "visibility_new" SET NOT NULL,
  DROP COLUMN "visibility";

-- @m063_2026_06_use_enum_for_visibility__set_cleanup_columns_2
ALTER TABLE "set"
  RENAME COLUMN "visibility_new" TO "visibility";

-- @m063_2026_06_use_enum_for_visibility__book_cleanup_columns_1
ALTER TABLE "book"
  ALTER COLUMN "visibility_new" SET NOT NULL,
  DROP COLUMN "visibility";

-- @m063_2026_06_use_enum_for_visibility__book_cleanup_columns_2
ALTER TABLE "book"
  RENAME COLUMN "visibility_new" TO "visibility";

-- @m064_2026_06_use_enum_for_page_type__create_type_page_type
CREATE TYPE "page_type" AS ENUM ('Part', 'Dance_only', 'Dance_versions', 'Dance_set', 'Versions', 'Set');

-- @m064_2026_06_use_enum_for_page_type__add_column_page_type_new
ALTER TABLE "book_content" ADD COLUMN "page_type_new" "page_type";

-- @m064_2026_06_use_enum_for_page_type__convert_part
UPDATE "book_content" SET "page_type_new" = 'Part' WHERE "page_type" = 0;

-- @m064_2026_06_use_enum_for_page_type__convert_dance_only
UPDATE "book_content" SET "page_type_new" = 'Dance_only' WHERE "page_type" = 1;

-- @m064_2026_06_use_enum_for_page_type__convert_dance_versions
UPDATE "book_content" SET "page_type_new" = 'Dance_versions' WHERE "page_type" = 2;

-- @m064_2026_06_use_enum_for_page_type__convert_dance_set
UPDATE "book_content" SET "page_type_new" = 'Dance_set' WHERE "page_type" = 3;

-- @m064_2026_06_use_enum_for_page_type__convert_versions
UPDATE "book_content" SET "page_type_new" = 'Versions' WHERE "page_type" = 4;

-- @m064_2026_06_use_enum_for_page_type__convert_set
UPDATE "book_content" SET "page_type_new" = 'Set' WHERE "page_type" = 5;

-- @m064_2026_06_use_enum_for_page_type__cleanup_columns_1
ALTER TABLE "book_content"
  ALTER COLUMN "page_type_new" SET NOT NULL,
  DROP COLUMN "page_type";

-- @m064_2026_06_use_enum_for_page_type__cleanup_columns_2
ALTER TABLE "book_content"
  RENAME COLUMN "page_type_new" TO "page_type";

-- @m065_2026_06_use_enum_for_type__create_type_type
CREATE TYPE "type" AS ENUM ('Person', 'User', 'Dance', 'Source', 'Tune', 'Version', 'Set', 'Book');

-- @m065_2026_06_use_enum_for_type__add_column_type_new
ALTER TABLE "globally_unique_id" ADD COLUMN "type_new" "type";

-- @m065_2026_06_use_enum_for_type__convert_person
UPDATE "globally_unique_id" SET "type_new" = 'Person' WHERE "type" = 'Person';

-- @m065_2026_06_use_enum_for_type__convert_user
UPDATE "globally_unique_id" SET "type_new" = 'User' WHERE "type" = 'User';

-- @m065_2026_06_use_enum_for_type__convert_dance
UPDATE "globally_unique_id" SET "type_new" = 'Dance' WHERE "type" = 'Dance';

-- @m065_2026_06_use_enum_for_type__convert_source
UPDATE "globally_unique_id" SET "type_new" = 'Source' WHERE "type" = 'Source';

-- @m065_2026_06_use_enum_for_type__convert_tune
UPDATE "globally_unique_id" SET "type_new" = 'Tune' WHERE "type" = 'Tune';

-- @m065_2026_06_use_enum_for_type__convert_version
UPDATE "globally_unique_id" SET "type_new" = 'Version' WHERE "type" = 'Version';

-- @m065_2026_06_use_enum_for_type__convert_set
UPDATE "globally_unique_id" SET "type_new" = 'Set' WHERE "type" = 'Set';

-- @m065_2026_06_use_enum_for_type__convert_book
UPDATE "globally_unique_id" SET "type_new" = 'Book' WHERE "type" = 'Book';

-- @m065_2026_06_use_enum_for_type__cleanup_columns_1
ALTER TABLE "globally_unique_id"
  ALTER COLUMN "type_new" SET NOT NULL,
  DROP COLUMN "type";

-- @m065_2026_06_use_enum_for_type__cleanup_columns_2
ALTER TABLE "globally_unique_id"
  RENAME COLUMN "type_new" TO "type";

-- @m066_2026_06_rename_table_globally_unique_id__table
ALTER TABLE "globally_unique_id" RENAME TO "entry";

-- @m066_2026_06_rename_table_globally_unique_id__drop_primary_key__for_sqlgg
ALTER TABLE "entry" DROP PRIMARY KEY;

-- @m066_2026_06_rename_table_globally_unique_id__add_primary_key__for_sqlgg
ALTER TABLE "entry" ADD CONSTRAINT "pk_entry" PRIMARY KEY ("id");

-- @m067_2026_06_move_created_update_at_to_entry_table__add_columns_to_entry
ALTER TABLE "entry"
  ADD COLUMN "created_at" TIMESTAMP,
  ADD COLUMN "modified_at" TIMESTAMP;

-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_person
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_user
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_source
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_dance
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_tune
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_version
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_set
-- @m067_2026_06_move_created_update_at_to_entry_table__copy_from_book

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_person_columns
ALTER TABLE "person"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_user_columns
ALTER TABLE "user"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_source_columns
ALTER TABLE "source"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_dance_columns
ALTER TABLE "dance"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_tune_columns
ALTER TABLE "tune"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_version_columns
ALTER TABLE "version"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_set_columns
ALTER TABLE "set"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__drop_book_columns
ALTER TABLE "book"
  DROP COLUMN "created_at",
  DROP COLUMN "modified_at";

-- @m067_2026_06_move_created_update_at_to_entry_table__cleanup_null
DELETE FROM "entry"
  WHERE "created_at" IS NULL;

-- @m067_2026_06_move_created_update_at_to_entry_table__make_columns_not_null
ALTER TABLE "entry"
  ALTER COLUMN "created_at" SET NOT NULL,
  ALTER COLUMN "modified_at" SET NOT NULL;

-- @m068_2026_06_move_access_to_entry_table__add_visibility_to_entry
ALTER TABLE "entry"
  ADD COLUMN "visibility" "visibility";

-- @m068_2026_06_move_access_to_entry_table__create_table_entry_viewers
CREATE TABLE "entry_viewers" (
    "entry_id" VARCHAR(14) NOT NULL,
    "viewer_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_entry_viewers_entry_id" FOREIGN KEY ("entry_id") REFERENCES "entry" ("id"),
    CONSTRAINT "fk_entry_viewers_viewer_id" FOREIGN KEY ("viewer_id") REFERENCES "user" ("id"),
    CONSTRAINT "uq_entry_viewers_entry_id_viewer_id" UNIQUE ("entry_id", "viewer_id")
);

-- @m068_2026_06_move_access_to_entry_table__create_table_entry_owners
CREATE TABLE "entry_owners" (
    "entry_id" VARCHAR(14) NOT NULL,
    "owner_id" VARCHAR(14) NOT NULL,
    CONSTRAINT "fk_entry_owners_entry_id" FOREIGN KEY ("entry_id") REFERENCES "entry" ("id"),
    CONSTRAINT "fk_entry_owners_owner_id" FOREIGN KEY ("owner_id") REFERENCES "user" ("id"),
    CONSTRAINT "uq_entry_owners_entry_id_owner_id" UNIQUE ("entry_id", "owner_id")
);

-- @m068_2026_06_move_access_to_entry_table__copy_set_viewers
INSERT INTO "entry_viewers" ("entry_id", "viewer_id") SELECT "set_id", "viewer_id" FROM "set_viewers";

-- @m068_2026_06_move_access_to_entry_table__copy_set_owners
INSERT INTO "entry_owners" ("entry_id", "owner_id") SELECT "set_id", "owner_id" FROM "set_owners";

-- @m068_2026_06_move_access_to_entry_table__copy_book_viewers
INSERT INTO "entry_viewers" ("entry_id", "viewer_id") SELECT "book_id", "viewer_id" FROM "book_viewers";

-- @m068_2026_06_move_access_to_entry_table__copy_book_owners
INSERT INTO "entry_owners" ("entry_id", "owner_id") SELECT "book_id", "owner_id" FROM "book_owners";

-- @m068_2026_06_move_access_to_entry_table__set_drop_column_visibility
ALTER TABLE "set"
  DROP COLUMN "visibility";

-- @m068_2026_06_move_access_to_entry_table__book_drop_column_visibility
ALTER TABLE "book"
  DROP COLUMN "visibility";

-- @m068_2026_06_move_access_to_entry_table__drop_table_set_viewers
DROP TABLE "set_viewers";

-- @m068_2026_06_move_access_to_entry_table__drop_table_set_owners
DROP TABLE "set_owners";

-- @m068_2026_06_move_access_to_entry_table__drop_table_book_viewers
DROP TABLE "book_viewers";

-- @m068_2026_06_move_access_to_entry_table__drop_table_book_owners
DROP TABLE "book_owners";

-- @m069_2026_06_use_enum_for_tune_kind__create_kind_role
CREATE TYPE "kind" AS ENUM ('Jig', 'Reel', 'Strathspey', 'Waltz', 'Polka', 'Jig_9_8', 'Other');

-- @m069_2026_06_use_enum_for_tune_kind__add_column_kind_new
ALTER TABLE "tune" ADD COLUMN "kind_new" "kind";

-- @m069_2026_06_use_enum_for_tune_kind__get_all_kinds
SELECT "id", "kind" FROM "tune";

-- @m069_2026_06_use_enum_for_tune_kind__update_one_kind_new
UPDATE "tune" SET "kind_new" = @kind_new WHERE "id" = @id;

-- @m069_2026_06_use_enum_for_tune_kind__cleanup_columns
ALTER TABLE "tune"
  ALTER COLUMN "kind_new" SET NOT NULL,
  DROP COLUMN "kind";

-- @m069_2026_06_use_enum_for_tune_kind__rename_column
ALTER TABLE "tune"
  RENAME COLUMN "kind_new" TO "kind";

-- @m070_2026_07_name_search__create_extension_unaccent
-- @m070_2026_07_name_search__create_function_name_search

-- @m070_2026_07_name_search__add_column_person_name_search
ALTER TABLE "person"
  ADD COLUMN "name_search" text
  GENERATED ALWAYS AS ("make_name_search"(name)) STORED;

-- @m070_2026_07_name_search__add_column_dance_name_search
ALTER TABLE "dance"
  ADD COLUMN "name_search" text
  GENERATED ALWAYS AS ("make_name_search"(name)) STORED;

-- @m070_2026_07_name_search__add_column_source_name_search
ALTER TABLE "source"
  ADD COLUMN "name_search" text
  GENERATED ALWAYS AS ("make_name_search"(name)) STORED;

-- @m070_2026_07_name_search__add_column_tune_name_search
ALTER TABLE "tune"
  ADD COLUMN "name_search" text
  GENERATED ALWAYS AS ("make_name_search"(name)) STORED;

-- @m070_2026_07_name_search__add_column_set_name_search
ALTER TABLE "set"
  ADD COLUMN "name_search" text
  GENERATED ALWAYS AS ("make_name_search"(name)) STORED;

-- @m070_2026_07_name_search__add_column_book_name_search
ALTER TABLE "book"
  ADD COLUMN "name_search" text
  GENERATED ALWAYS AS ("make_name_search"(name)) STORED;

-- @m070_2026_07_name_search__add_column_user_username_search
ALTER TABLE "user"
  ADD COLUMN "username_search" text
  GENERATED ALWAYS AS ("make_name_search"(username)) STORED;

-- @m070_2026_07_name_search__add_column_dance_extra_name_search
ALTER TABLE "dance_extra_names"
  ADD COLUMN "extra_name_search" text
  GENERATED ALWAYS AS ("make_name_search"(extra_name)) STORED;

-- @m070_2026_07_name_search__add_column_tune_extra_name_search
ALTER TABLE "tune_extra_names"
  ADD COLUMN "extra_name_search" text
  GENERATED ALWAYS AS ("make_name_search"(extra_name)) STORED;

-- @m071_2026_07_move_pg_trgm_to_public
-- @m072_2026_07_gin_indices

-- @m073_2026_08_user_github_handle
ALTER TABLE "user" ADD COLUMN "github_handle" VARCHAR(64);

-- @m074_2026_09_entry_replace_visibility_by_is_public__add_column
ALTER TABLE "entry" ADD COLUMN "is_public" BOOLEAN;

-- @m074_2026_09_entry_replace_visibility_by_is_public__migrate
UPDATE "entry" SET "is_public" = ("visibility" IS NULL OR "visibility" = 'Everyone');

-- @m074_2026_09_entry_replace_visibility_by_is_public__cleanup_columns
ALTER TABLE "entry" ALTER COLUMN "is_public" SET NOT NULL, DROP COLUMN "visibility";

-- @m074_2026_09_entry_replace_visibility_by_is_public__drop_type
DROP TYPE "visibility";
