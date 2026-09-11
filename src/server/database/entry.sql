-- @get_type
SELECT "type" FROM "entry"
WHERE "id" = @id;

-- @get_is_public
SELECT "is_public" FROM "entry"
WHERE "id" = @id;

-- @register
INSERT INTO "entry" (
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
DELETE FROM "entry" WHERE "id" = @id;

-- @touch
UPDATE "entry"
SET "modified_at" = CURRENT_TIMESTAMP
WHERE "id" = @id;

-- @update_is_public
UPDATE "entry"
SET "is_public" = @is_public
WHERE "id" = @id;

-- @get_actors
SELECT "user_id", "role"
FROM "entry_actors"
WHERE "entry_id" = @entry_id;

-- @get_all_actors
SELECT
    "entry_id",
    "user_id",
    "role"
FROM "entry_actors"
JOIN "entry" ON "entry_actors"."entry_id" = "entry"."id"
WHERE "type" = @type_;

-- @delete_all_actors
DELETE FROM "entry_actors"
WHERE "entry_id" = @entry_id;

-- @add_one_actor
INSERT INTO "entry_actors" (
    "entry_id",
    "user_id",
    "role"
) VALUES (
    @entry_id,
    @user_id,
    @role
);

-- @get_newest
WITH "entry_permissions" AS &get_entry_permissions
SELECT "id", "type"
FROM "entry" JOIN "entry_permissions" USING ("id")
ORDER BY "created_at" DESC
LIMIT @limit;
