-- @get
SELECT
    "name",
    "kind",
    "remark",
    "scddb_id",
    "date",
    "created_at",
    "modified_at"
FROM "tune"
JOIN "entry" ON "tune"."id" = "entry"."id"
WHERE "tune"."id" = @id
LIMIT 1; -- NOTE: to help sqlgg

-- @create
INSERT INTO "tune" (
    "id",
    "name",
    "kind",
    "remark",
    "scddb_id",
    "date"
) VALUES (
    @id,
    @name,
    @kind,
    @remark,
    @scddb_id,
    @date
);

-- @update
UPDATE "tune"
SET
    "name" = @name,
    "kind" = @kind,
    "remark" = @remark,
    "scddb_id" = @scddb_id,
    "date" = @date
WHERE "id" = @id;

-- @delete
DELETE FROM "tune"
WHERE "id" = @id;

-- @get_extra_names
SELECT
    "extra_name"
FROM "tune_extra_names"
WHERE "tune_id" = @tune_id
ORDER BY "extra_name";

-- @get_all_extra_names
SELECT
    "tune_id",
    "extra_name"
FROM "tune_extra_names"
ORDER BY "tune_id", "extra_name";

-- @delete_all_extra_names
DELETE FROM "tune_extra_names"
WHERE "tune_id" = @tune_id;

-- @add_one_extra_name
INSERT INTO "tune_extra_names" (
    "tune_id",
    "extra_name"
) VALUES (
    @tune_id,
    @extra_name
);

-- @get_composers
SELECT
    "composer_id",
    "details"
FROM "tune_composers"
WHERE "tune_id" = @tune_id
ORDER BY "index";

-- @get_all_composers
SELECT
    "tune_id",
    "composer_id",
    "details"
FROM "tune_composers"
ORDER BY "tune_id", "index";

-- @delete_all_composers
DELETE FROM "tune_composers"
WHERE "tune_id" = @tune_id;

-- @add_one_composer
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

-- @get_dances
SELECT
    "dance_id"
FROM "recommended_tunes"
WHERE "tune_id" = @tune_id;

-- @get_all_dances
SELECT
    "tune_id",
    "dance_id"
FROM "recommended_tunes";

-- @delete_all_dances
DELETE FROM "recommended_tunes"
WHERE "tune_id" = @tune_id;

-- @add_one_dance
INSERT INTO "recommended_tunes" (
    "tune_id",
    "dance_id"
) VALUES (
    @tune_id,
    @dance_id
);

-- NEW MODELS

-- @get_rows
WITH "tunes" AS &get_tune_rows
SELECT *
FROM "tunes"
WHERE "id" IN @ids;

-- @get_view
WITH "tunes" AS &get_tune_views
SELECT *
FROM "tunes"
WHERE "id" = @id;

-- @search
WITH "tune_rows" AS &get_tune_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "tune"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "tune_rows".*
FROM "tune"
JOIN "tune_rows" ON "tune"."id" = "tune_rows"."id"
WHERE
    (@terms = '' OR @terms <% "tune"."name" OR make_name_search(@terms) <% "name_search")
    AND { "tune"."kind" IN @kind }?
    AND @composer { Some { EXISTS (SELECT 1 FROM "tune_composers" WHERE "tune_id" = "tune"."id" AND "composer_id" IN @composer) } | None { TRUE } }
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @get_extra_names_for
SELECT
    "tune_id",
    "extra_name"
FROM "tune_extra_names"
WHERE @tune_ids { One_of { "tune_id" IN @tune_ids } | All { TRUE } }
ORDER BY "extra_name";

-- @get_composers_for
WITH "persons" AS &get_person_rows
SELECT
    "tune_id",
    "persons".*
FROM "tune_composers"
JOIN "persons" ON "tune_composers"."composer_id" = "persons"."id"
WHERE @tune_ids { One_of { "tune_id" IN @tune_ids } | All { TRUE } }
ORDER BY "index";

-- @get_composers_for_tunes_of_dances
WITH "tunes" AS &get_tune_ids_for_dances,
     "persons" AS &get_person_rows
SELECT "tunes"."tune_id", "persons".*
FROM "tune_composers"
JOIN "persons" ON "tune_composers"."composer_id" = "persons"."id"
JOIN "tunes" ON "tune_composers"."tune_id" = "tunes"."tune_id"
ORDER BY "index";

-- @get_composers_with_details_for
WITH "persons" AS &get_person_rows
SELECT "tune_id", "persons".*, "details"
FROM "tune_composers"
JOIN "persons" ON "tune_composers"."composer_id" = "persons"."id"
WHERE @tune_ids { One_of { "tune_id" IN @tune_ids } | All { TRUE } }
ORDER BY "index";

-- @get_dances_for
WITH "dances" AS &get_dance_rows
SELECT "tune_id", "dances".*
FROM "recommended_tunes"
JOIN "dances" ON "recommended_tunes"."dance_id" = "dances"."id"
WHERE @tune_ids { One_of { "recommended_tunes"."tune_id" IN @tune_ids } | All { TRUE } };

-- @get_dance_ids_for_tunes | include: reuse
SELECT DISTINCT "dance_id"
FROM "recommended_tunes"
WHERE @tune_ids { One_of { "tune_id" IN @tune_ids } | All { TRUE } };

-- @get_devisers_for_dances_of
WITH "dances" AS &get_dance_ids_for_tunes,
     "persons" AS &get_person_rows
SELECT "dances"."dance_id", "persons".*
FROM "dance_devisers"
JOIN "persons" ON "dance_devisers"."deviser_id" = "persons"."id"
JOIN "dances" ON "dance_devisers"."dance_id" = "dances"."dance_id";

-- @get_versions_for
WITH "versions" AS &get_version_rows
SELECT *
FROM "versions"
WHERE @tune_ids { One_of { "tune_id" IN @tune_ids } | All { TRUE } };

-- @get_sources_for_versions_of
WITH "sources" AS &get_source_short_names
SELECT "version_id", "sources".*
FROM "version_sources"
JOIN "version" ON "version_sources"."version_id" = "version"."id"
JOIN "sources" ON "version_sources"."source_id" = "sources"."id"
WHERE @tune_ids { One_of { "version"."tune_id" IN @tune_ids } | All { TRUE } };

-- @get_arrangers_for_versions_of
WITH "persons" AS &get_person_rows
SELECT "version_id", "persons".*
FROM "version_arrangers"
JOIN "version" ON "version_arrangers"."version_id" = "version"."id"
JOIN "persons" ON "version_arrangers"."arranger_id" = "persons"."id"
WHERE @tune_ids { One_of { "version"."tune_id" IN @tune_ids } | All { TRUE } };

-- @get_rows_for_dance
WITH "tunes" AS &get_tune_rows
SELECT "tunes".*
FROM "recommended_tunes"
JOIN "tunes" ON "recommended_tunes"."tune_id" = "tunes"."id"
WHERE "dance_id" = @dance_id;
