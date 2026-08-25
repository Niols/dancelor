--------------------------------- [ Entries ] ----------------------------------

-- @get_entry_permissions | include: reuse
SELECT * FROM (
    SELECT
        "entry"."id",
        CASE
            WHEN "entry"."visibility" = 'Everyone' THEN 'Everyone'
            WHEN "entry_owners"."owner_id" IS NOT NULL THEN 'Owner'
            WHEN "entry"."visibility" = 'Select_viewers' AND "entry_viewers"."viewer_id" IS NOT NULL THEN 'Viewer'
            WHEN "user"."role" = 'Administrator' AND "user"."omniscience" THEN 'Omniscient_administrator'
            ELSE NULL
        END AS "permission"
    FROM "entry"
    LEFT JOIN "entry_owners" ON "entry_owners"."entry_id" = "entry"."id" AND "entry_owners"."owner_id" = (@user_id :: TEXT NULL)
    LEFT JOIN "entry_viewers" ON "entry_viewers"."entry_id" = "entry"."id" AND "entry_viewers"."viewer_id" = (@user_id :: TEXT NULL)
    LEFT JOIN "user" ON "user"."id" = (@user_id :: TEXT NULL)
) AS "entry+"
WHERE "entry+"."permission" IS NOT NULL;

--------------------------------- [ Persons ] ----------------------------------

-- @get_person_rows | include: reuse
SELECT
    "id",
    "name"
FROM "person";

-- @get_person_views | include: reuse
SELECT
    "id",
    "name",
    "scddb_id",
    "composed_tunes_are_public",
    "published_tunes_are_public"
FROM "person";

--------------------------------- [ Sources ] ----------------------------------

-- @get_source_rows | include: reuse
SELECT
    "id",
    "name",
    "date"
FROM "source";

-- @get_source_views | include: reuse
SELECT
    "id",
    "name",
    "short_name",
    "scddb_id",
    "description",
    "date"
FROM "source";

-- @get_source_names | include: reuse
SELECT
    "id",
    "name"
FROM "source";

-- @get_source_short_names | include: reuse
SELECT
    "id",
    "name",
    "short_name"
FROM "source";

--------------------------------- [ Dances ] -----------------------------------

-- @get_dance_rows | include: reuse
SELECT
    "id",
    "name",
    "kind",
    "disambiguation"
FROM "dance";

-- @get_dance_views | include: reuse
SELECT
    "id",
    "name",
    "kind",
    "scddb_id",
    "disambiguation",
    "date",
    "two_chords"
FROM "dance";

---------------------------------- [ Users ] -----------------------------------

-- @get_user_rows | include: reuse
SELECT
    "id",
    "username"
FROM "user";

---------------------------------- [ Tunes ] -----------------------------------

-- @get_tune_rows | include: reuse
SELECT
    "id",
    "name",
    "kind"
FROM "tune";

-- @get_tune_views | include: reuse
SELECT
    "id",
    "name",
    "kind",
    "remark",
    "scddb_id",
    "date"
FROM "tune";

---------------------------------- [ Tunes ] -----------------------------------

-- @get_tune_ids_for_dances | include: reuse
SELECT DISTINCT "tune_id"
FROM "recommended_tunes"
WHERE @dance_ids { One_of { "dance_id" IN @dance_ids } | All { TRUE } };

-- @get_version_rows | include: reuse
SELECT
    "id",
    "tune_id",
    "disambiguation",
    "monolithic_bars",
    "monolithic_or_default_structure"
FROM "version";

-- @get_version_and_tune_rows | include: reuse
WITH "versions" AS &get_version_rows
SELECT
    "versions".*,
    "tune"."name" AS "tune_name",
    "tune"."kind" AS "tune_kind"
FROM "versions"
JOIN "tune" ON "versions"."tune_id" = "tune"."id";

-- @get_version_views | include: reuse
SELECT
    -- ids
    "version"."id",
    "tune"."id" AS "tune_id",
    -- version
    "version"."disambiguation",
    "version"."key",
    "version"."remark",
    "version"."monolithic_bars",
    "version"."monolithic_or_default_structure",
    -- tune
    "tune"."name" AS "tune_name",
    "tune"."kind" AS "tune_kind",
    "tune"."remark" AS "tune_remark",
    "tune"."scddb_id" AS "tune_scddb_id",
    "tune"."date" AS "tune_date"
FROM "version"
JOIN "tune" ON "version"."tune_id" = "tune"."id";

-- @get_version_names | include: reuse
SELECT
    "version"."id",
    "tune"."name"
FROM "version"
JOIN "tune" ON "tune"."id" = "version"."tune_id";

---------------------------------- [ Sets ] ------------------------------------

-- @get_set_rows | include: reuse
WITH entries AS &get_entry_permissions
SELECT
    "set"."id",
    "name",
    "kind",
    "permission"
FROM "set"
JOIN "entries" ON "entries"."id" = "set"."id";

-- @get_set_views | include: reuse
WITH entries AS &get_entry_permissions
SELECT
    "set"."id",
    "name",
    "kind",
    "order",
    "remark",
    "permission"
FROM "set"
JOIN "entries" ON "entries"."id" = "set"."id";

-- @get_set_contents | include: reuse
SELECT
    -- ids
    "set_id",
    "version_id",
    "tune_id",
    -- version
    "version"."disambiguation" AS "version_disambiguation",
    "version"."monolithic_bars" AS "version_monolithic_bars",
    "version"."monolithic_or_default_structure" AS "version_monolithic_or_default_structure",
    -- tune
    "name" AS "tune_name",
    "kind" AS "tune_kind",
    -- version parameters
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
FROM "set_content"
JOIN "version" ON "set_content"."version_id" = "version"."id"
JOIN "tune" ON "version"."tune_id" = "tune"."id"
ORDER BY "index";

---------------------------------- [ Books ] -----------------------------------

-- @get_book_rows | include: reuse
WITH "entries" AS &get_entry_permissions
SELECT
    "book"."id",
    "name",
    "date",
    "permission"
FROM "book"
JOIN "entries" ON "entries"."id" = "book"."id";

-- @get_book_views | include: reuse
WITH "entries" AS &get_entry_permissions
SELECT
    "book"."id",
    "name",
    "date",
    "remark",
    "scddb_id",
    "permission"
FROM "book"
JOIN "entries" ON "entries"."id" = "book"."id";
