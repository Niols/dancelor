-- @get_type_unsafe
SELECT "type" FROM "entities"
WHERE "id" = @id;

-- @get_is_public
SELECT "is_public" FROM "entities"
WHERE "id" = @id;

-- @register
INSERT INTO "entities" (
    "id",
    "type",
    "created_at",
    "modified_at",
    "is_public"
) VALUES (
    @id,
    @type_,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP,
    @is_public
);

-- @delete
DELETE FROM "entities" WHERE "id" = @id;

-- @touch
UPDATE "entities"
SET "modified_at" = CURRENT_TIMESTAMP
WHERE "id" = @id;

-- @update_is_public
UPDATE "entities"
SET "is_public" = @is_public
WHERE "id" = @id;

-- @get_actors
SELECT "user_id", "role"
FROM "entity_actors"
WHERE "entity_id" = @entity_id;

-- @get_all_actors
SELECT
    "entity_id",
    "user_id",
    "role"
FROM "entity_actors"
JOIN "entities" ON "entity_actors"."entity_id" = "entities"."id"
WHERE "type" = @type_;

-- @delete_all_actors
DELETE FROM "entity_actors"
WHERE "entity_id" = @entity_id;

-- @add_one_actor
INSERT INTO "entity_actors" (
    "entity_id",
    "user_id",
    "role"
) VALUES (
    @entity_id,
    @user_id,
    @role
);

-- @get_newest
WITH "viewable_entities" AS &viewable_entities
SELECT "id", "type"
FROM "entities" JOIN "viewable_entities" USING ("id")
ORDER BY "created_at" DESC
LIMIT @limit;

-- @get_permission
WITH "entities" AS &viewable_entities
SELECT "entity_is_public", "actor_role", "actor_is_omniscient_administrator"
FROM "entities"
WHERE "id" = @id;

-- @get_actor_roles
WITH "users" AS &get_user_rows
SELECT
    "entity_actors"."role",
    "users".*
FROM "entity_actors"
JOIN "users" ON "entity_actors"."user_id" = "users"."id"
WHERE "entity_id" = @entity_id;

-- @set_is_public
UPDATE "entities"
SET "is_public" = @is_public
WHERE "id" = @id;

-- @get_type
WITH "viewable_entities" AS &viewable_entities
SELECT "entities"."type"
FROM "viewable_entities"
JOIN "entities" USING ("id")
WHERE "id" = @id
LIMIT 1; -- NOTE: to help sqlgg
