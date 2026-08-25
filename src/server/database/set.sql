-- @get
SELECT
    "name",
    "kind",
    "order",
    "remark",
    "created_at",
    "modified_at",
    "visibility"
FROM "set"
JOIN "entry" ON "set"."id" = "entry"."id"
WHERE "set"."id" = @id
LIMIT 1; -- NOTE: to help sqlgg

-- @create
INSERT INTO "set" (
    "id",
    "name",
    "kind",
    "order",
    "remark"
) VALUES (
    @id,
    @name,
    @kind,
    @order,
    @remark
);

-- @update
UPDATE "set"
SET
    "name" = @name,
    "kind" = @kind,
    "order" = @order,
    "remark" = @remark
WHERE "id" = @id;

-- @delete
DELETE FROM "set"
WHERE "id" = @id;

-- @get_conceptors
SELECT "conceptor_id"
FROM "set_conceptors"
WHERE "set_id" = @set_id;

-- @get_all_conceptors
SELECT
    "set_id",
    "conceptor_id"
FROM "set_conceptors";

-- @delete_all_conceptors
DELETE FROM "set_conceptors"
WHERE "set_id" = @set_id;

-- @add_one_conceptor
INSERT INTO "set_conceptors" (
    "set_id",
    "conceptor_id"
) VALUES (
    @set_id,
    @conceptor_id
);

-- @get_content
SELECT
    "version_id",
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
FROM "set_content"
WHERE "set_id" = @set_id
ORDER BY "index";

-- @get_all_content
SELECT
    "set_id",
    "version_id",
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
FROM "set_content"
ORDER BY "set_id", "index";

-- @delete_all_content
DELETE FROM "set_content"
WHERE "set_id" = @set_id;

-- @add_one_content_item
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

-- NEW MODELS

-- @get_rows
WITH "sets" AS &get_set_rows
SELECT *
FROM "sets"
WHERE "sets"."id" IN @ids;

-- @get_view
WITH "sets" AS &get_set_views
SELECT *
FROM "sets"
WHERE "sets"."id" = @id;

-- @search
WITH "set_rows" AS &get_set_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "set"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "set_rows".*
FROM "set"
JOIN "set_rows" ON "set"."id" = "set_rows"."id"
WHERE
    (@terms = '' OR @terms <% "set"."name" OR make_name_search(@terms) <% "name_search")
    AND @conceptor { Some { EXISTS (SELECT 1 FROM "set_conceptors" WHERE "set_id" = "set"."id" AND "conceptor_id" IN @conceptor) } | None { TRUE } }
    AND @contains_version { Some { EXISTS (SELECT 1 FROM "set_content" WHERE "set_id" = "set"."id" AND "version_id" IN @contains_version ) } | None { TRUE } }
    AND @contains_tune { Some { EXISTS (SELECT 1 FROM "set_content" JOIN "version" ON "set_content"."version_id" = "version"."id" WHERE "set_content"."set_id" = "set"."id" AND "version"."tune_id" IN @contains_tune ) } | None { TRUE } }
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @get_conceptors_for
WITH "persons" AS &get_person_rows
SELECT
    "set_id",
    "persons".*
FROM "set_conceptors"
JOIN "persons" ON "set_conceptors"."conceptor_id" = "persons"."id"
WHERE @set_ids { One_of { "set_id" IN @set_ids } | All { TRUE } };

-- @get_tunes_for
WITH "versions" AS &get_version_names
SELECT
    "set_id",
    "versions".*
FROM "set_content"
JOIN "versions" ON "set_content"."version_id" = "versions"."id"
WHERE @set_ids { One_of { "set_id" IN @set_ids } | All { TRUE } }
ORDER BY "index";

-- @get_content_for
WITH "set_contents" AS &get_set_contents
SELECT *
FROM "set_contents"
WHERE @set_ids { One_of { "set_id" IN @set_ids } | All { TRUE } };

-- @get_version_ids_in_set | include: reuse
SELECT DISTINCT "version_id"
FROM "set_content"
WHERE @set_ids { One_of { "set_id" IN @set_ids } | All { TRUE } };

-- @get_tune_ids_in_set | include: reuse
SELECT DISTINCT "tune_id"
FROM "set_content"
JOIN "version" ON "set_content"."version_id" = "version"."id"
WHERE @set_ids { One_of { "set_id" IN @set_ids } | All { TRUE } };

-- @get_tune_composers_for
WITH "tunes" AS &get_tune_ids_in_set,
     "persons" AS &get_person_rows
SELECT "tune_id", "persons".*
FROM "tunes"
JOIN "tune_composers" USING ("tune_id")
JOIN "persons" ON "tune_composers"."composer_id" = "persons"."id"
ORDER BY "tune_composers"."index";

-- @get_version_sources_for
WITH "versions" AS &get_version_ids_in_set,
     "sources" AS &get_source_short_names
SELECT "version_id", "sources".*
FROM "versions"
JOIN "version_sources" USING ("version_id")
JOIN "sources" ON "version_sources"."source_id" = "sources"."id";

-- @get_version_arrangers_for
WITH "versions" AS &get_version_ids_in_set,
     "persons" AS &get_person_rows
SELECT "version_id", "persons".*
FROM "versions"
JOIN "version_arrangers" USING ("version_id")
JOIN "persons" ON "version_arrangers"."arranger_id" = "persons"."id";
