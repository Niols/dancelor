-- @get
SELECT
    "name",
    "scddb_id",
    "composed_tunes_are_public",
    "published_tunes_are_public",
    "created_at",
    "modified_at"
FROM "person"
JOIN "entry" ON "person"."id" = "entry"."id"
WHERE "person"."id" = @id
LIMIT 1; -- NOTE: to help sqlgg

-- NEW MODELS

-- @get_rows
WITH "persons" AS &get_person_rows
SELECT "persons".*
FROM "persons"
WHERE "id" IN @ids;

-- @get_view
WITH "persons" AS &get_person_views
SELECT "persons".*
FROM "persons"
WHERE "id" = @id;

-- @get_form
WITH "persons" AS &get_person_forms
SELECT "persons".*
FROM "persons"
WHERE "id" = @id;

-- @search
WITH "person_rows" AS &get_person_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "person"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "person_rows".*
FROM "person"
JOIN "person_rows" ON "person"."id" = "person_rows"."id"
WHERE (@terms = '' OR @terms <% "person"."name" OR make_name_search(@terms) <% "name_search")
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @create
INSERT INTO "person" (
    "id",
    "name",
    "scddb_id",
    "composed_tunes_are_public",
    "published_tunes_are_public"
)
VALUES (
    @id,
    @name,
    @scddb_id,
    FALSE,
    FALSE
);

-- @update
UPDATE "person"
SET
    "name" = @name,
    "scddb_id" = @scddb_id
WHERE "id" = @id;

-- @delete
DELETE FROM "person"
WHERE "id" = @id;
