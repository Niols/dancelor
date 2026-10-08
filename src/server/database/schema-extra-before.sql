-- NOTE: For schema elements that sqlgg cannot parse, plus the extensions that
-- they depend on. This file will be included before `schema.sql` in tests only.

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;

CREATE FUNCTION make_name_search(TEXT) RETURNS TEXT
           LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
	   AS $$ SELECT regexp_replace(lower("public"."unaccent"($1)), '^(the|an?)\s+(.+)$', '\2, \1') $$;
