-- @get_rows
WITH "persons" AS &person_rows
SELECT "persons".*
FROM "persons"
WHERE "id" IN @ids;

-- @get_view
SELECT
    "id",
    "name",
    "copyright_name",
    "scddb_id",
    "composed_tunes_are_public",
    "published_tunes_are_public"
FROM "persons"
WHERE "id" = @id;

-- @get_form
SELECT
    "id",
    "name",
    "copyright_name",
    "scddb_id"
FROM "persons"
WHERE "id" = @id;

-- @search
WITH "person_rows" AS &person_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "persons"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "person_rows".*
FROM "persons"
JOIN "person_rows" ON "persons"."id" = "person_rows"."id"
WHERE (@terms = '' OR @terms <% "persons"."name" OR make_name_search(@terms) <% "name_search")
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @create
INSERT INTO "persons" (
    "id",
    "name",
    "copyright_name",
    "scddb_id",
    "composed_tunes_are_public",
    "published_tunes_are_public"
)
VALUES (
    @id,
    @name,
    @copyright_name,
    @scddb_id,
    FALSE,
    FALSE
);

-- @update
UPDATE "persons"
SET
    "name" = @name,
    "copyright_name" = @copyright_name,
    "scddb_id" = @scddb_id
WHERE "id" = @id;

-- @delete
DELETE FROM "persons"
WHERE "id" = @id;
