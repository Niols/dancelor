-- @get_from_username
SELECT
    "users"."id",
    "role",
    "omniscience",
    "github_handle",
    "created_at",
    "modified_at"
FROM "users"
JOIN "entities" ON "users"."id" = "entities"."id"
WHERE "username" = @username
LIMIT 1; -- NOTE: to help sqlgg

-- @get_password_from_username
SELECT
    "password"
FROM "users"
WHERE "username" = @username;

-- @get_password_reset_token_from_username
SELECT
    "password_reset_token_hash",
    "password_reset_token_max_date"
FROM "users"
WHERE "username" = @username;

-- @create
INSERT INTO "users" (
    "id",
    "username",
    "full_name",
    "email",
    "password_reset_token_hash",
    "password_reset_token_max_date",
    "role",
    "github_handle",
    "omniscience"
)
VALUES (
    @id,
    @username,
    @full_name,
    @email,
    @password_reset_token_hash,
    @password_reset_token_max_date,
    'Normal_user', -- FIXME: make this a default in the schema
    NULL, -- FIXME: make this a default in the schema
    FALSE -- FIXME: make this a default in the schema
);

-- @update
UPDATE "users"
SET
    "username" = @username,
    "full_name" = @full_name,
    "email" = @email
WHERE "id" = @id;

-- @set_password_reset_token
UPDATE "users"
SET
    "password" = NULL,
    "password_reset_token_hash" = @password_reset_token_hash,
    "password_reset_token_max_date" = @password_reset_token_max_date
WHERE "id" = @id;

-- @remove_all_remember_me_tokens
DELETE FROM "remember_me_tokens"
WHERE "user_id" = @user_id;

-- @remove_one_remember_me_token
DELETE FROM "remember_me_tokens"
WHERE "user_id" = @user_id AND "key" = @key;

-- @find_remember_me_token
SELECT
    "hash",
    "max_date"
FROM "remember_me_tokens"
WHERE "user_id" = @user_id AND "key" = @key;

-- @add_remember_me_token
INSERT INTO "remember_me_tokens" (
    "user_id",
    "key",
    "hash",
    "max_date"
)
VALUES (
    @user_id,
    @key,
    @hash,
    @max_date
);

-- @set_password
UPDATE "users"
SET
    "password" = @password,
    "password_reset_token_hash" = NULL,
    "password_reset_token_max_date" = NULL
WHERE "id" = @id;

-- @set_omniscience
UPDATE "users"
SET
    "omniscience" = @omniscience
WHERE "id" = @id;

-- @get_rows
WITH "users" AS &user_rows
SELECT *
FROM "users"
WHERE "id" IN @ids;

-- @get_view
SELECT
    "username",
    "full_name",
    "created_at" AS "joined"
FROM "users"
JOIN "entities" USING ("id")
WHERE "id" = @id
LIMIT 1;

-- @get_form
SELECT
    "username",
    "full_name",
    "email"
FROM "users"
WHERE "id" = @id;

-- @actors | include: reuse
SELECT
    "users"."id",
    "username",
    "full_name",
    "github_handle",
    "role",
    "omniscience",
    "person_id",
    "persons"."name" AS "person_name"
FROM "users"
LEFT JOIN "persons" ON "users"."person_id" = "persons"."id";

-- @get_actor
WITH "actors" AS &actors
SELECT * FROM "actors"
WHERE "id" = @id;

-- @get_actor_from_username
WITH "actors" AS &actors
SELECT * FROM "actors"
WHERE "username" = @username;

-- @search
WITH "user_rows" AS &user_rows
SELECT
    CASE
        WHEN @terms = '' THEN 1.0
	ELSE GREATEST(word_similarity(@terms, "users"."username"), word_similarity(make_name_search(@terms), "username_search"))
    END AS "score",
    "user_rows".*
FROM "users"
JOIN "user_rows" ON "users"."id" = "user_rows"."id"
WHERE (@terms = '' OR @terms <% "users"."username" OR make_name_search(@terms) <% "username_search")
ORDER BY "score" DESC, "username_search" ASC, "username" ASC;

-- @groups_for
WITH "groups" AS &group_rows
SELECT
    "group_members"."member_id" AS "user_id",
    "groups".*
FROM "groups"
JOIN "group_members" ON "group_members"."group_id" = "groups"."id"
WHERE @user_ids { One_of { "member_id" IN @user_ids } | All { TRUE } };
