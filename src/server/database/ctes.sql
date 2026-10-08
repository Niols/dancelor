-- @viewable_entities | include: reuse
WITH
    -- grab the information of whether the actor is an omniscient administrator
    "actor" AS (
        SELECT COALESCE((
            SELECT "user"."role" = 'Administrator' AND "user"."omniscience"
            FROM "user"
            WHERE "user"."id" = (@actor_id :: TEXT NULL)
        ), FALSE) AS "actor_is_omniscient_administrator"
    ),

    -- The list of groups the actor is in.
    "actor_groups" AS (
        SELECT "group_id" FROM "group_members"
        WHERE "member_id" = (@actor_id :: TEXT NULL)
    ),

    -- Every permissions that applies to the actor, directly or through one of their groups.
    -- This table can be empty if the actor never appears in "entity_actors".
    --
    -- FIXME: DISTINCT because the unique constraint on "entity_actors" does not
    -- rule out duplicate group grants: "user_id" is NULL on those, and
    -- PostgreSQL counts NULLs as distinct in a UNIQUE constraint. I think that
    -- means the constraint in question is just useless and should be cleaned up?
    "actor_permissions" AS (
        SELECT DISTINCT
            "entity_actors"."entity_id",
            "entity_actors"."role" AS "actor_role",
            "groups"."id" AS "actor_group_id",
            "groups"."name" AS "actor_group_name"
        FROM "entity_actors"
        LEFT JOIN "groups" ON "entity_actors"."group_id" = "groups"."id"
        WHERE
            "user_id" = (@actor_id :: TEXT NULL)
            OR "group_id" IN (SELECT "group_id" FROM "actor_groups") -- FIXME: JOIN "groups" but also "actor_groups"?
    ),

    -- Of the above permissions, keep the best one, expressed as “there does not
    -- exist a permission that is better”.
    "best_actor_permissions" AS (
        SELECT *
        FROM "actor_permissions" AS "this"
        WHERE NOT EXISTS (
            SELECT 1
            FROM "actor_permissions" AS "better"
            WHERE
                "better"."entity_id" = "this"."entity_id"
                AND (
                    -- a better role wins
                    "better"."actor_role" < "this"."actor_role"
                    OR (
                        -- at equal role, direct access beats access through a group
                        "better"."actor_role" = "this"."actor_role"
                        AND "better"."actor_group_id" IS NULL
                        AND "this"."actor_group_id" IS NOT NULL
                    )
                    OR (
                        -- at equal role and both through a group, take the lowest
                        -- group id, so as to remain deterministic
                        "better"."actor_role" = "this"."actor_role"
                        AND "better"."actor_group_id" IS NOT NULL
                        AND "this"."actor_group_id" IS NOT NULL
                        AND "better"."actor_group_id" < "this"."actor_group_id"
                    )
                )
        )
    )

SELECT
    "entities"."id",
    "entities"."is_public" AS "entity_is_public",
    "actor_role", -- NULL if no actor access
    "actor_group_id", -- NULL if no actor access or direct access, an id if access via a group
    "actor_group_name", -- NULL if no actor access or direct access, a name if access via a group
    "actor_is_omniscient_administrator"
FROM "entities"
CROSS JOIN "actor"
LEFT JOIN "best_actor_permissions" ON "best_actor_permissions"."entity_id" = "entities"."id"
WHERE
    "entities"."is_public"
    OR "actor_role" IS NOT NULL
    OR "actor_is_omniscient_administrator";

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
