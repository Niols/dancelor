-- @create
INSERT INTO "groups" (
    "id",
    "name"
)
VALUES (
    @id,
    @name
);

-- @update
UPDATE "groups"
SET
    "name" = @name
WHERE "id" = @id;

-- @get_rows
WITH "groups" AS &group_rows
SELECT *
FROM "groups"
WHERE "id" IN @ids;

-- @get_view
SELECT "name"
FROM "groups"
WHERE "id" = @id
LIMIT 1;

-- @get_form
SELECT "name"
FROM "groups"
WHERE "id" = @id;

-- @search
WITH "group_rows" AS &group_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "groups"."name"), word_similarity(make_name_search(@terms), "name_search"))
    END AS "score",
    "group_rows".*
FROM "groups"
JOIN "group_rows" ON "groups"."id" = "group_rows"."id"
WHERE (@terms = '' OR @terms <% "groups"."name" OR make_name_search(@terms) <% "name_search")
ORDER BY "score" DESC, "name_search" ASC, "name" ASC;

-- @get_members_for
WITH "users" AS &user_rows
SELECT "group_id", "users".*
FROM "users"
JOIN "group_members" ON "group_members"."member_id" = "users"."id"
WHERE @group_ids { One_of { "group_members"."group_id" IN @group_ids } | All { TRUE } };

-- @get_members
SELECT
    "member_id"
FROM "group_members"
WHERE "group_id" = @group_id;

-- @get_all_members
SELECT
    "group_id",
    "member_id"
FROM "group_members";

-- @delete_all_members
DELETE FROM "group_members"
WHERE "group_id" = @group_id;

-- @add_one_member
INSERT INTO "group_members" (
    "group_id",
    "member_id"
) VALUES (
    @group_id,
    @member_id
);
