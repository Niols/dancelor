-- @create
INSERT INTO "dances" (
    "id",
    "name",
    "kind",
    "two_chords",
    "scddb_id",
    "disambiguation",
    "date"
) VALUES (
    @id,
    @name,
    @kind,
    @two_chords,
    @scddb_id,
    @disambiguation,
    @date
);

-- @update
UPDATE "dances"
SET
    "name" = @name,
    "kind" = @kind,
    "two_chords" = @two_chords,
    "scddb_id" = @scddb_id,
    "disambiguation" = @disambiguation,
    "date" = @date
WHERE "id" = @id;

-- @delete
DELETE FROM "dances"
WHERE "id" = @id;

-- @delete_all_extra_names
DELETE FROM "dance_extra_names"
WHERE "dance_id" = @dance_id;

-- @add_one_extra_name
INSERT INTO "dance_extra_names" (
    "dance_id",
    "extra_name"
) VALUES (
    @dance_id,
    @extra_name
);

-- @delete_all_devisers
DELETE FROM "dance_devisers"
WHERE "dance_id" = @dance_id;

-- @add_one_deviser
INSERT INTO "dance_devisers" (
    "dance_id",
    "index",
    "deviser_id"
) VALUES (
    @dance_id,
    @index,
    @deviser_id
);

-- @delete_all_tunes
DELETE FROM "recommended_tunes"
WHERE "dance_id" = @dance_id;

-- @add_one_tune
INSERT INTO "recommended_tunes" (
    "dance_id",
    "tune_id"
) VALUES (
    @dance_id,
    @tune_id
);

-- @get_rows
WITH "dances" AS &dance_rows
SELECT *
FROM "dances"
WHERE @ids { One_of { "id" IN @ids } | All { TRUE } };

-- @get_view
SELECT
    "id",
    "name",
    "kind",
    "scddb_id",
    "disambiguation",
    "date",
    "two_chords"
FROM "dances"
WHERE "id" = @id;

-- @get_form
SELECT
    "id",
    "name",
    "kind",
    "scddb_id",
    "disambiguation",
    "date",
    "two_chords"
FROM "dances"
WHERE "id" = @id;

-- @search
WITH "dance_rows" AS &dance_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "dances"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "dance_rows".*
FROM "dances"
JOIN "dance_rows" ON "dances"."id" = "dance_rows"."id"
WHERE
    (@terms = '' OR @terms <% "dances"."name" OR make_name_search(@terms) <% "name_search")
    AND @deviser { Some { EXISTS (SELECT 1 FROM "dance_devisers" WHERE "dance_id" = "dances"."id" AND "deviser_id" IN @deviser) } | None { TRUE } }
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @get_extra_names_for
SELECT
    "dance_id",
    "extra_name"
FROM "dance_extra_names"
WHERE @dance_ids { One_of { "dance_id" IN @dance_ids } | All { TRUE } }
ORDER BY "extra_name";

-- @get_devisers_for
WITH "persons" AS &person_rows
SELECT
    "dance_id",
    "persons".*
FROM "dance_devisers"
JOIN "persons" ON "dance_devisers"."deviser_id" = "persons"."id"
WHERE @dance_ids { One_of { "dance_id" IN @dance_ids } | All { TRUE } }
ORDER BY "index";

-- @get_tunes_for
SELECT
    "dance_id",
    "id",
    "name",
    "kind"
FROM "recommended_tunes"
JOIN "tunes" ON "recommended_tunes"."tune_id" = "tunes"."id"
WHERE @dance_ids { One_of { "recommended_tunes"."dance_id" IN @dance_ids } | All { TRUE } };

-- @get_composers_for_tunes_for
WITH "tunes" AS &tune_ids_for_dances
SELECT
    "tune_id",
    "persons"."id",
    "persons"."name"
FROM "tune_composers"
JOIN "persons" ON "tune_composers"."composer_id" = "persons"."id"
JOIN "tunes" USING ("tune_id")
ORDER BY "index";
