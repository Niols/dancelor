-- @create
INSERT INTO "source" (
    "id",
    "name",
    "short_name",
    "scddb_id",
    "description",
    "date"
) VALUES (
    @id,
    @name,
    @short_name,
    @scddb_id,
    @description,
    @date
);

-- @get_editors
SELECT
    "person_id"
FROM "source_editors"
WHERE "source_id" = @source_id;

-- @get_all_editors
SELECT
    "source_id",
    "person_id"
FROM "source_editors";

-- @delete_all_editors
DELETE FROM "source_editors"
WHERE "source_id" = @source_id;

-- @add_one_editor
INSERT INTO "source_editors" (
    "source_id",
    "person_id"
) VALUES (
    @source_id,
    @person_id
);

-- @update
UPDATE "source"
SET
    "name" = @name,
    "short_name" = @short_name,
    "scddb_id" = @scddb_id,
    "description" = @description,
    "date" = @date
WHERE "id" = @id;

-- @delete
DELETE FROM "source"
WHERE "id" = @id;

-- @get_cover
SELECT "cover"
FROM "source"
WHERE "id" = @id;

-- @get_rows
WITH "sources" AS &source_rows
SELECT "sources".*
FROM "sources"
WHERE "id" IN @ids;

-- @get_view
SELECT
    "id",
    "name",
    "short_name",
    "scddb_id",
    "description",
    "date"
FROM "source"
WHERE "id" = @id;

-- @get_form
SELECT
    "id",
    "name",
    "short_name",
    "scddb_id",
    "description",
    "date"
FROM "source"
WHERE "id" = @id;

-- @search
WITH "source_rows" AS &source_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "source"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "source_rows".*
FROM "source"
JOIN "source_rows" ON "source"."id" = "source_rows"."id"
WHERE
    (@terms = '' OR @terms <% "source"."name" OR make_name_search(@terms) <% "name_search")
    AND @editor { Some { EXISTS (SELECT 1 FROM "source_editors" WHERE "source_id" = "source"."id" AND "person_id" IN @editor) } | None { TRUE } }
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @get_editors_for
WITH "persons" AS &person_rows
SELECT
    "source_id",
    "persons".*
FROM "source_editors"
JOIN "persons" ON "source_editors"."person_id" = "persons"."id"
WHERE @source_ids { One_of { "source_id" IN @source_ids } | All { TRUE } };
