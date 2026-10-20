.PHONY: build run entr clean postgres-start postgres-reset postgres-dump postgres-reset-run-dump

build:
	dune build @install @runtest

run: postgres-start build
	dune exec dancelor -- assets/config.dev.json

entr: postgres-start
	watchexec --clear --restart -- 'dune build @install @runtest && dune exec dancelor -- assets/config.dev.json'

postgres-start:
	@scripts/postgres-start

postgres-reset:
	@scripts/postgres-reset

postgres-dump:
	@scripts/postgres-dump

postgres-reset-run-dump:
	scripts/postgres-reset
	scripts/postgres-start
	dune exec dancelor -- <(jq '.test.init_only |= true' assets/config.dev.json)
	scripts/postgres-dump

clean: postgres-reset
	dune clean
