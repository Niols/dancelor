-- @viewable_entities | include: reuse
SELECT *
FROM (
    SELECT
        "entities"."id",
        "entities"."is_public" AS "entity_is_public",
        "entity_actors"."role" AS "actor_role",
        COALESCE(
            ("user"."role" = 'Administrator' AND "user"."omniscience"),
            FALSE
        ) AS "actor_is_omniscient_administrator"
    FROM "entities"
    LEFT JOIN "entity_actors" ON "entity_actors"."entity_id" = "entities"."id" AND "entity_actors"."user_id" = (@actor_id :: TEXT NULL)
    LEFT JOIN "user" ON "user"."id" = (@actor_id :: TEXT NULL)
) AS "sub"
WHERE
    "sub"."entity_is_public"
    OR "sub"."actor_role" IS NOT NULL
    OR "sub"."actor_is_omniscient_administrator";

-- @person_rows | include: reuse
SELECT
    "id",
    "name"
FROM "person";

-- @source_rows | include: reuse
SELECT
    "id",
    "name",
    "date"
FROM "source";

-- @source_names | include: reuse
SELECT
    "id",
    "name"
FROM "source";

-- @source_short_names | include: reuse
SELECT
    "id",
    "name",
    "short_name"
FROM "source";

-- @dance_rows | include: reuse
SELECT
    "id",
    "name",
    "kind",
    "disambiguation"
FROM "dance";

-- @user_rows | include: reuse
SELECT
    "id",
    "username"
FROM "user";

-- @group_rows | include: reuse
SELECT "id", "name"
FROM "groups";

-- @tune_ids_for_dances | include: reuse
SELECT DISTINCT "tune_id"
FROM "recommended_tunes"
WHERE @dance_ids { One_of { "dance_id" IN @dance_ids } | All { TRUE } };

-- @version_rows | include: reuse
SELECT
    "id",
    "tune_id",
    "disambiguation",
    "monolithic_bars",
    "monolithic_or_default_structure"
FROM "version";

-- @version_names | include: reuse
SELECT
    "version"."id",
    "tune"."name"
FROM "version"
JOIN "tune" ON "tune"."id" = "version"."tune_id";
