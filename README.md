# db-tool

db-tool is a tool that helps developers playtest database migrations on a copied databases before running the same migrations on the main ("golden") database. 


## How to use it
Currently the tool is hardcoded to Gradle, Flyway and PostgreSQL.

### Prerequisite
* You need to have your main database up and running (psql database).
* Make sure `flyway.properties.example` and `db-tool` is in your root folder, rename `flyway.properties.example` into `flyway.properties`and add it into .gitignore.
* `gradle.properties` must have line `flyway.configFiles=flyway.properties` in it.
### Setup
Run command in terminal:
```
./db-tool init --dbname <database_name>
```
* `<database_name>` is replaced with the real "golden" database name that will be used.
* `--dbname` saves template database name.
* `ìnit` will write the given name as the active url, and activates git hooks.

###  The tool is activated
After setup is complete there is no need to interact with the tool until cleanup step, because git hooks will do the work in the background.\
Switching to a branch now activates the hook and creates a copied database for that branch named `<database_name>-<branch_name>`. 
It also changes the Flyway URL respectively in the `flyway.properties`, showing Flyway to connect into the copied database.
Switching back to the main branch will change the URL back to the "golden" database.
### Cleanup
Run the command:
```
./db-tool cleanup
```
This shows all copies made using the template database. For dropping the database there are 2 choices:
```
./db-tool cleanup <database_name>
```
`<database_name>` here is 1 of the chosen database names from the available database list.\
This command drops ONLY the given database.
```
./db-tool cleanup all
```
`all` is a flag that drops all copied databases from the available list.
