-- @get_from_username
SELECT
    "user"."id",
    "role",
    "omniscience",
    "github_handle",
    "created_at",
    "modified_at"
FROM "user"
JOIN "entities" ON "user"."id" = "entities"."id"
WHERE "username" = @username
LIMIT 1; -- NOTE: to help sqlgg

-- @get_password_from_username
SELECT
    "password"
FROM "user"
WHERE "username" = @username;

-- @get_password_reset_token_from_username
SELECT
    "password_reset_token_hash",
    "password_reset_token_max_date"
FROM "user"
WHERE "username" = @username;

-- @create
INSERT INTO "user" (
    "id",
    "username",
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
    @email,
    @password_reset_token_hash,
    @password_reset_token_max_date,
    'Normal_user', -- FIXME: make this a default in the schema
    NULL, -- FIXME: make this a default in the schema
    FALSE -- FIXME: make this a default in the schema
);

-- @update
UPDATE "user"
SET
    "username" = @username,
    "email" = @email
WHERE "id" = @id;

-- @set_password_reset_token
UPDATE "user"
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
UPDATE "user"
SET
    "password" = @password,
    "password_reset_token_hash" = NULL,
    "password_reset_token_max_date" = NULL
WHERE "id" = @id;

-- @set_omniscience
UPDATE "user"
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
    "created_at" AS "joined"
FROM "user"
JOIN "entities" USING ("id")
WHERE "id" = @id
LIMIT 1;

-- @get_form
SELECT
    "username",
    "email"
FROM "user"
WHERE "id" = @id;

-- @actors | include: reuse
SELECT
    "user"."id",
    "username",
    "github_handle",
    "role",
    "omniscience",
    "person_id",
    "person"."name" AS "person_name"
FROM "user"
LEFT JOIN "person" ON "user"."person_id" = "person"."id";

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
	ELSE GREATEST(word_similarity(@terms, "user"."username"), word_similarity(make_name_search(@terms), "username_search"))
    END AS "score",
    "user_rows".*
FROM "user"
JOIN "user_rows" ON "user"."id" = "user_rows"."id"
WHERE (@terms = '' OR @terms <% "user"."username" OR make_name_search(@terms) <% "username_search")
ORDER BY "score" DESC, "username_search" ASC, "username" ASC;
