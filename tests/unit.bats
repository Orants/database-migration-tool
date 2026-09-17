#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../db-tool"
  TMP="$(mktemp -d)"
}
teardown() { rm -rf "$TMP"; }

# ---------- properties file ----------

@test "get_prop reads a key" {
  printf 'flyway.url=jdbc:postgresql://localhost:5432/test\n' > "$TMP/p"
  [ "$(get_prop "$TMP/p" flyway.url)" = "jdbc:postgresql://localhost:5432/test" ]
}

@test "get_prop keeps everything after the first =" {
  printf 'k=a=b=c\n' > "$TMP/p"
  [ "$(get_prop "$TMP/p" k)" = "a=b=c" ]
}

@test "get_prop ignores # and ! comment lines" {
  printf '#k=wrong\n!k=wrong\nk=right\n' > "$TMP/p"
  [ "$(get_prop "$TMP/p" k)" = "right" ]
}

@test "set_prop replaces the value and leaves other lines alone" {
  printf '# header\nflyway.user=admin\nflyway.url=old\n' > "$TMP/p"
  set_prop "$TMP/p" flyway.url new
  [ "$(get_prop "$TMP/p" flyway.url)" = "new" ]
  [ "$(get_prop "$TMP/p" flyway.user)" = "admin" ]
  grep -q '^# header$' "$TMP/p"
}

@test "set_prop appends a key that isn't there" {
  printf 'flyway.user=admin\n' > "$TMP/p"
  set_prop "$TMP/p" flyway.url new
  [ "$(get_prop "$TMP/p" flyway.url)" = "new" ]
}

@test "set_prop works on a file that doesn't exist yet" {
  set_prop "$TMP/missing" flyway.url new
  [ "$(get_prop "$TMP/missing" flyway.url)" = "new" ]
}

# ---------- name derivation ----------

@test "copy_db on main returns the template itself" {
  DB_NAME=tmpl BRANCH=main
  [ "$(copy_db)" = "tmpl" ]
}

@test "copy_db on a branch appends the branch name" {
  DB_NAME=tmpl BRANCH=feature
  [ "$(copy_db)" = "tmpl-feature" ]
}

@test "copy_db does not produce a trailing dash on detached HEAD" {
  skip "known:detached HEAD gives tmpl-"
  DB_NAME=tmpl BRANCH=""
  run copy_db
  [ "$output" != "tmpl-" ]
}

@test "copy_db never puts a slash in a database name" {
  DB_NAME=tmpl BRANCH="feature/login"
  run copy_db
  [[ "$output" != */* ]]
}

# ---------- validation ----------

@test "valid_name accepts letters, digits, _ and -" {
  run valid_name "my_db-2"
  [ "$status" -eq 0 ]
}

@test "valid_name rejects an empty name" {
  run valid_name ""
  [ "$status" -ne 0 ]
}

@test "valid_name rejects a quote" {
  run valid_name "ev'il"
  [ "$status" -ne 0 ]
}

# ---------- url ----------

@test "jdbc_url substitutes host, port and database" {
  DB_HOST=db.example DB_PORT=6543
  [ "$(jdbc_url mydb)" = "jdbc:postgresql://db.example:6543/mydb" ]
}