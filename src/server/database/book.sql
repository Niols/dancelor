-- @get
SELECT
    "name",
    "date",
    "remark",
    "scddb_id",
    "created_at",
    "modified_at",
    "visibility"
FROM "book"
JOIN "entry" ON "book"."id" = "entry"."id"
WHERE "book"."id" = @id
LIMIT 1; -- NOTE: to help sqlgg

-- @create
INSERT INTO "book" (
    "id",
    "name",
    "date",
    "remark",
    "scddb_id"
) VALUES (
    @id,
    @name,
    @date,
    @remark,
    @scddb_id
);

-- @update
UPDATE "book"
SET
    "name" = @name,
    "date" = @date,
    "remark" = @remark,
    "scddb_id" = @scddb_id
WHERE "id" = @id;

-- @delete
DELETE FROM "book"
WHERE "id" = @id;

-- @get_authors
SELECT "author_id"
FROM "book_authors"
WHERE "book_id" = @book_id;

-- @get_all_authors
SELECT
    "book_id",
    "author_id"
FROM "book_authors";

-- @delete_all_authors
DELETE FROM "book_authors"
WHERE "book_id" = @book_id;

-- @add_one_author
INSERT INTO "book_authors" (
    "book_id",
    "author_id"
) VALUES (
    @book_id,
    @author_id
);

-- @get_sources
SELECT "source_id"
FROM "book_sources"
WHERE "book_id" = @book_id;

-- @get_all_sources
SELECT
    "book_id",
    "source_id"
FROM "book_sources";

-- @delete_all_sources
DELETE FROM "book_sources"
WHERE "book_id" = @book_id;

-- @add_one_source
INSERT INTO "book_sources" (
    "book_id",
    "source_id"
) VALUES (
    @book_id,
    @source_id
);

-- @get_content
SELECT
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
FROM "book_content"
WHERE "book_id" = @book_id
ORDER BY "index";

-- @get_all_content
SELECT
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
FROM "book_content"
ORDER BY "book_id", "index";

-- @delete_all_content
DELETE FROM "book_content"
WHERE "book_id" = @book_id;

-- @add_one_content_item
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

-- @get_content_versions
SELECT
    "content_index",
    "version_id",
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
FROM "book_content_versions"
WHERE "book_id" = @book_id
ORDER BY "content_index", "index";

-- @get_all_content_versions
SELECT
    "book_id",
    "content_index",
    "version_id",
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
FROM "book_content_versions"
ORDER BY "book_id", "content_index", "index";

-- @delete_all_content_versions
DELETE FROM "book_content_versions"
WHERE "book_id" = @book_id;

-- @add_one_content_version
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

-- NEW MODELS

-- @get_rows
WITH "books" AS &get_book_rows
SELECT *
FROM "books"
WHERE "books"."id" IN @ids;

-- @get_view
WITH "books" AS &get_book_views
SELECT *
FROM "books"
WHERE "books"."id" = @id;

-- @search
WITH "book_rows" AS &get_book_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "book"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "book_rows".*
FROM "book"
JOIN "book_rows" ON "book"."id" = "book_rows"."id"
WHERE
    (@terms = '' OR @terms <% "book"."name" OR make_name_search(@terms) <% "name_search")
    AND @author { Some { EXISTS (SELECT 1 FROM "book_authors" WHERE "book_id" = "book"."id" AND "author_id" IN @author) } | None { TRUE } }
    AND @contains_version { Some {
	    EXISTS (SELECT 1 FROM "book_content" JOIN "set_content" USING ("set_id") WHERE "book_content"."book_id" = "book"."id" AND "set_content"."version_id" IN @contains_version )
	    OR EXISTS (SELECT 1 FROM "book_content_versions" WHERE "book_id" = "book"."id" AND "version_id" IN @contains_version)
	} | None { TRUE } }
    AND @contains_tune { Some {
	    EXISTS (SELECT 1 FROM "book_content" JOIN "set_content" USING ("set_id") JOIN "version" ON "set_content"."version_id" = "version"."id" WHERE "book_content"."book_id" = "book"."id" AND "version"."tune_id" IN @contains_tune )
	    OR EXISTS (SELECT 1 FROM "book_content_versions" JOIN "version" ON "book_content_versions"."version_id" = "version"."id" WHERE "book_content_versions"."book_id" = "book"."id" AND "version"."tune_id" IN @contains_tune)
	} | None { TRUE } }
    AND @contains_set { Some { EXISTS (SELECT 1 FROM "book_content" WHERE "book_id" = "book"."id" AND "set_id" IN @contains_set ) } | None { TRUE } }
ORDER BY "score" DESC, "name_search" ASC, "name" ASC, "id" ASC;

-- @get_authors_for
WITH "persons" AS &get_person_rows
SELECT
    "book_id",
    "persons".*
FROM "book_authors"
JOIN "persons" ON "book_authors"."author_id" = "persons"."id"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } };

-- @get_sources_for
WITH "sources" AS &get_source_names
SELECT
    "book_id",
    "sources".*
FROM "book_sources"
JOIN "sources" ON "book_sources"."source_id" = "sources"."id"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } };

-- @get_content_for
WITH "set_permissions" AS &get_entry_permissions
SELECT
    "book_id",
    "page_type",
    "index",
    -- part
    "part_title",
    -- dance
    "dance_id",
    "dance"."name" AS "dance_name",
    "dance"."kind" AS "dance_kind",
    "dance"."disambiguation" AS "dance_disambiguation",
    -- set
    "set_id",
    "set"."name" AS "set_name",
    "set"."kind" AS "set_kind",
    "set_permissions"."permission" AS "set_permission",
    -- set parameters
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
FROM "book_content"
LEFT JOIN "dance" ON "book_content"."dance_id" = "dance"."id"
LEFT JOIN "set" ON "book_content"."set_id" = "set"."id"
LEFT JOIN "set_permissions" ON "set"."id" = "set_permissions"."id"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } }
ORDER BY "index";

-- @get_content_versions_for
SELECT
    "book_id",
    "content_index",
    -- version
    "version_id",
    "tune_id",
    "version"."disambiguation" AS "version_disambiguation",
    "version"."monolithic_bars" AS "version_monolithic_bars",
    "version"."monolithic_or_default_structure" AS "version_monolithic_or_default_structure",
    "tune"."name" AS "tune_name",
    "tune"."kind" AS "tune_kind",
    -- version parameters
    "version_parameter_transposition_semitones",
    "version_parameter_first_bar",
    "version_parameter_clef",
    "version_parameter_structure",
    "version_parameter_trivia",
    "version_parameter_display_name",
    "version_parameter_display_composer"
FROM "book_content_versions"
JOIN "version" ON "book_content_versions"."version_id" = "version"."id"
JOIN "tune" ON "version"."tune_id" = "tune"."id"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } }
ORDER BY "index";

-- @get_version_ids_in_book | include: reuse
SELECT DISTINCT "version_id"
FROM "book_content_versions"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } };

-- @get_tune_ids_in_book | include: reuse
SELECT DISTINCT "tune_id"
FROM "book_content_versions"
JOIN "version" ON "book_content_versions"."version_id" = "version"."id"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } };

-- @get_set_ids_in_book | include: reuse
SELECT DISTINCT "set_id"
FROM "book_content"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } };

-- @get_dance_ids_in_book | include: reuse
SELECT DISTINCT "dance_id"
FROM "book_content"
WHERE @book_ids { One_of { "book_id" IN @book_ids } | All { TRUE } };

-- @get_tune_composers_for
WITH "tunes" AS &get_tune_ids_in_book,
     "persons" AS &get_person_rows
SELECT "tune_id", "persons".*
FROM "tunes"
JOIN "tune_composers" USING ("tune_id")
JOIN "persons" ON "tune_composers"."composer_id" = "persons"."id"
ORDER BY "tune_composers"."index";

-- @get_version_sources_for
WITH "versions" AS &get_version_ids_in_book,
     "sources" AS &get_source_short_names
SELECT "version_id", "sources".*
FROM "versions"
JOIN "version_sources" USING ("version_id")
JOIN "sources" ON "version_sources"."source_id" = "sources"."id";

-- @get_version_arrangers_for
WITH "versions" AS &get_version_ids_in_book,
     "persons" AS &get_person_rows
SELECT "version_id", "persons".*
FROM "versions"
JOIN "version_arrangers" USING ("version_id")
JOIN "persons" ON "version_arrangers"."arranger_id" = "persons"."id";

-- @get_set_conceptors_for
WITH "sets" AS &get_set_ids_in_book,
     "persons" AS &get_person_rows
SELECT "set_id", "persons".*
FROM "set_conceptors"
JOIN "persons" ON "set_conceptors"."conceptor_id" = "persons"."id"
JOIN "sets" USING ("set_id");

-- @get_set_tunes_for
WITH "sets" AS &get_set_ids_in_book,
     "versions" AS &get_version_names
SELECT "set_id", "versions".*
FROM "set_content"
JOIN "sets" USING ("set_id")
JOIN "versions" ON "set_content"."version_id" = "versions"."id"
ORDER BY "set_content"."index";

-- @get_dance_devisers_for
WITH "dances" AS &get_dance_ids_in_book,
     "persons" AS &get_person_rows
SELECT "dance_id", "persons".*
FROM "dance_devisers"
JOIN "persons" ON "dance_devisers"."deviser_id" = "persons"."id"
JOIN "dances" USING ("dance_id")
ORDER BY "dance_devisers"."index";
