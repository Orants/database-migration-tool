#!/usr/bin/env bats

setup() {
  psql -d postgres -c 'SELECT 1' >/dev/null 2>&1 || skip "postgres not reachable"

  TMPL="dbtool_it_$$_$RANDOM"
  REPO="$(mktemp -d)"
  createdb "$TMPL"

  git -C "$REPO" init -q -b main
  git -C "$REPO" config user.email t@example.com
  git -C "$REPO" config user.name test
  cp "$BATS_TEST_DIRNAME/../db-tool" "$REPO/"
  mkdir -p "$REPO/project_example"
  printf 'flyway.user=%s\n' "$(whoami)" > "$REPO/flyway.properties"
}

teardown() {
  if [ -n "${TMPL:-}" ]; then
    psql -d postgres -Atc \
      "select datname from pg_database where datname like '${TMPL}%'" 2>/dev/null |
      while read -r d; do dropdb --if-exists --force "$d" >/dev/null 2>&1 || true; done
  fi
  [ -n "${REPO:-}" ] && rm -rf "$REPO"
}

@test "init writes the url into flyway.properties at the repo root" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  run grep '^flyway.url=' "$REPO/flyway.properties"
  [[ "$output" == *"/$TMPL" ]]
}

@test "the installed hook passes the template to copy" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  grep -q "copy \"$TMPL\"" "$REPO/.git/hooks/post-checkout"
}

@test "copy clones the template for a branch" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  git -C "$REPO" commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature
  ../db-tool copy "$TMPL"
  psql -lqt | cut -d'|' -f1 | grep -qw "$TMPL-feature"
}

@test "copy refuses a template that doesn't exist" {
  cd "$REPO/project_example"
  run ../db-tool copy "dbtool_missing_$$"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "cleanup never offers the template itself" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  run ../db-tool cleanup "$TMPL"
  [[ "$output" != *" - $TMPL"* ]]
}

@test "cleanup all drops every branch copy but keeps the template" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  createdb --template "$TMPL" "$TMPL-one"
  createdb --template "$TMPL" "$TMPL-two"

  printf 'y\n' | ../db-tool cleanup "$TMPL" all

  run psql -d postgres -Atc \
    "select count(*) from pg_database where datname in ('$TMPL-one','$TMPL-two')"
  [ "$output" = "0" ]

  run psql -d postgres -Atc \
    "select count(*) from pg_database where datname = '$TMPL'"
  [ "$output" = "1" ]
}

@test "cleanup <database> drops only that one" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  createdb --template "$TMPL" "$TMPL-one"
  createdb --template "$TMPL" "$TMPL-two"

  printf 'y\n' | ../db-tool cleanup "$TMPL" "$TMPL-one"

  run psql -d postgres -Atc \
    "select count(*) from pg_database where datname = '$TMPL-one'"
  [ "$output" = "0" ]

  run psql -d postgres -Atc \
    "select count(*) from pg_database where datname = '$TMPL-two'"
  [ "$output" = "1" ]
}

@test "copy repoints flyway.url at the branch copy" {
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  git -C "$REPO" commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature
  ../db-tool copy "$TMPL"

  run grep '^flyway.url=' "$REPO/flyway.properties"
  [[ "$output" == *"/$TMPL-feature" ]]
}

@test "the branch copy contains the template's rows" {
  psql -d "$TMPL" -c 'create table t (id int); insert into t values (1);'
  cd "$REPO/project_example"
  ../db-tool init --dbname "$TMPL"
  git -C "$REPO" commit -q --allow-empty -m init
  git -C "$REPO" checkout -q -b feature
  ../db-tool copy "$TMPL"

  run psql -d "$TMPL-feature" -Atc 'select count(*) from t'
  [ "$output" = "1" ]
}
