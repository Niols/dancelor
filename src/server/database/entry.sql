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

-- @get_viewers
SELECT "viewer_id"
FROM "entry_viewers"
WHERE "entry_id" = @entry_id;

-- @get_all_viewers
SELECT
    "entry_id",
    "viewer_id"
FROM "entry_viewers"
JOIN "entry" ON "entry_viewers"."entry_id" = "entry"."id"
WHERE "type" = @type_;

-- @delete_all_viewers
DELETE FROM "entry_viewers"
WHERE "entry_id" = @entry_id;

-- @add_one_viewer
INSERT INTO "entry_viewers" (
    "entry_id",
    "viewer_id"
) VALUES (
    @entry_id,
    @viewer_id
);

-- @get_owners
SELECT "owner_id"
FROM "entry_owners"
WHERE "entry_id" = @entry_id;

-- @get_all_owners
SELECT
    "entry_id",
    "owner_id"
FROM "entry_owners"
JOIN "entry" ON "entry_owners"."entry_id" = "entry"."id"
WHERE "type" = @type_;

-- @delete_all_owners
DELETE FROM "entry_owners"
WHERE "entry_id" = @entry_id;

-- @add_one_owner
INSERT INTO "entry_owners" (
    "entry_id",
    "owner_id"
) VALUES (
    @entry_id,
    @owner_id
);

-- @get_newest
WITH "entry_permissions" AS &get_entry_permissions
SELECT "id", "type"
FROM "entry" JOIN "entry_permissions" USING ("id")
ORDER BY "created_at" DESC
LIMIT @limit;
