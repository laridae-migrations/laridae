
<div align="center">
  <img width="300" src="https://i.ibb.co/q7FMJ9p/Transparent-Logo.png" alt="Laridae-Logo" >
</div>

# LARIDAE - Zero-downtime, reversible, schema migrations in PostgreSQL with prebuilt integration into GitHub Action workflows

Laridae is an open-source tool that enables reversible, zero-downtime schema migrations in PostgreSQL, synchronizing them with application code deployments for apps using ECS Fargate. It allows application instances expecting the pre-migration and post-migration schema to use the same database simultaneously without requiring changes to either version's code. Additionally, recent schema migrations can be reversed without data loss. This is accomplished with minimal interference with usual reads and writes to the database. For more details on Laridae, see our detailed write-up [here](https://laridae-migrations.github.io/).

**This repository only contains the code for the core functionality of performing schema migrations**. When used alone, the code in this repository provides a command-line tool to facilitate zero-downtime, minimal-locking database changes, allowing both new and old applications code to work simultaneously on the same database, as well as the ability to rollback schema changes.

The GitHub Action providing the CI/CD pipeline integration can be found [here](https://github.com/marketplace/actions/laridae-postgres-db-schema-migrations).

## Table of Contents
- [Installation](#installation)
- [Performing a Migration](#performing-a-migration)
- [Migration files](#migration-files)

## Installation
#### Clone the repository

```shell
git clone https://github.com/laridae-migrations/laridae
cd laridae
```

#### Check your Ruby version

```shell
ruby -v
```

The ouput should start with something like `ruby 3.2.1`

If not, install the right ruby version using [rbenv](https://github.com/rbenv/rbenv)

```shell
rbenv install 3.2.1
```

#### Install dependencies

Using [Bundler](https://github.com/bundler/bundler)

```shell
bundle
```

## Performing a Migration
Laridae is intended to be used when new application code requires an updated database schema. Before we show specific CLI commands, here's the overall flow:
* First, Laridae **expands** the database to tolerate both schema versions. The Laridae CLI outputs a new database URL that should be given to the new application code. (the URL references the existing database, but contains a connection control function which makes the new code access the updated schema). The old code using the existing URL continues to access the original schema.
* The new code is **deployed** manually by the user (if you are working with an automated deployment pipeline on GitHub Actions, see Laridae's integration [here](https://github.com/marketplace/actions/laridae-postgres-db-schema-migrations)).

After this, there are two options:
* If the old code has been scaled down, Laridae can **contract** the database to only present the updated schema.
* Alternatively, the migration can be **rolled back** so that the database is returned to its original form.

For much more detail on the expand-and-contract method and how Laridae automates it, see our write-up [here](https://laridae-migrations.github.io/#expand-and-contract).

### CLI Commands
On Windows, the `database_url` and `path_to_migration_file` arguments needs to be enclosed in double quotes `""`

### Database URL

The Database URL, also called the database connection string, is needed to run Laridae from the command line

Here's an example database URL: 
```shell
postgres://username:password@localhost:5432/my_database
```
### Migration file

Laridae requires a migration file, which is a JSON file containing details about the schema migration. 

The location of this file does not matter, as long as the location is supplied to `Laridae` at the time of execution (as explained below).

The details of the migration file format are presented [below](#migration-files).

All migration files are required to have a migration name, as specified in the `name` key. To avoid accidental duplication of migrations, a migration with the same name as the last migration which was applied using Laridae to a database will not be applied.

#### Initialization
Before running a migration, Laridae needs to be initialized. It creates a schema called `laridae` in your database where it stores its internal data.

For Linux:
```shell
./laridae init [database_url]
```

For Windows:
```shell
ruby laridae init [database_url]
```

#### Expand
For Linux:
```shell
./laridae expand [database_url] [path_to_migration_file]
```

For Windows:
```shell
ruby laridae expand [database_url] [path_to_migration_file]
```

#### Contract
Contract will only run on a database with a successfully expanded script. And aborted or failed expansion is not eligible for contraction.
Contract will remove the mechanisms Laridae uses to support multiple schema versions simultaneously, and put the database in a form where it only supports the new schema.

For Linux:
```shell
./laridae contract [database_url] [path_to_migration_file]
```

For Windows:
```shell
ruby laridae contract [database_url] [path_to_migration_file]
```

#### Rollback
Rollback will only run on a database with a successfully expanded script. And aborted or failed expansion is not eligible for rolling back.

For Linux:
```shell
./laridae rollback [database_url] [path_to_migration_file]
```

For Windows:
```shell
ruby laridae rollback [database_url] [path_to_migration_file]
```

## Migration files
### Supported migrations 

Currently, core `Laridae` functionality supports the following schema changes: 
- [Add a new column](#Add-a-new-column)
- [Add an index to an existing column](#Add-an-index)
- [Add a foreign key to an existing column](#Add-a-foreign-key)
- [Rename a column](#Rename-a-column)
- [Add a not-null constraint to an existing column](#Add-Not-NULL-constraint)
- [Add a unique constraint to an existing column](#Add-UNIQUE-constraint)
- [Add check constraint to an existing column](#Add-CHECK-constraint)
- [Drop a column](#Drop-column)
- [Change a column data type](#Change-data-type)
### `up` and `down` functions
Some operations modifying specific columns require `up` and `down` functions to specified in the migration script as strings containing SQL. The `up` function specifies how to transform existing data in the column so it fits the new schema, while the `down` function does the opposite: it specifies how data added to the new version of the column should be seen by old application versions.

Here's a brief example: suppose we have a column of type `char(12)` containing 12-digit strings representing US-phone phone numbers like `919-232-4243`. We want to change the type to `char(14)` to support phone numbers with a country code.

In this case, since the US has a country code of `1`, an existing phone number like `828-111-2234` should be seen by the new application as `1-828-111-2234`. Conversely, if `1-421-333-4727` is written by the new application, the old application should see `421-333-4727`. In this case, our up function is
```SQL
"1-" || phone
```
and our down function is
```SQL
SUBSTRING(phone, 3)
```
For more information on how Laridae propagates data behind the scenes, see our write-up [here](https://laridae-migrations.github.io/#data-propagation).
### Operations

#### Add a new column
```
{
  "name": "mmddyyy_migration_name",
  "operation": "add_column",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": {
      "name": "column_name",
      "type": "integer",
    },
  }
}
```

### Add an index 
The `method` field can be `btree`, `GiST`, or `GIN`
```
{
  "name": "mmddyyy_migration_name",
  "operation": "create_index",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
    "method": "btree",
  }
}
```

### Add a foreign key
```
{
  "name": "mmddyyy_migration_name",
  "operation": "add_foreign_key_constraint",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": {
      "name": "column_name",
      "references": {
        name: "foreign_key_name",
        table: "referenced_table_name",
        column: "referenced_column_name",
      },
    }
  },
  functions: {
    up: "SQL function to transfer data from old version of column",
    down: "SQL function to transfer data from new version of column"
  }
}
```

### Rename a column
```
{
  "name": "mmddyyy_migration_name",
  "operation": "rename_column",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
    "new_name": "new_column_name"
  }
}
```

### Add Not-NULL constraint
```
{
  "name": "mmddyyy_migration_name",
  "operation": "add_not_null_constraint",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
  },
  "functions": {
    up: "SQL function to transfer data from old version of column",
    down: "SQL function to transfer data from new version of column"
  }
}
```

### Add UNIQUE constraint
```
{
  "name": "mmddyyy_migration_name",
  "operation": "add_unique_constraint",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
  },
  "functions": {
    up: "SQL function to transfer data from old version of column",
    down: "SQL function to transfer data from new version of column"
  }
}
```

### Add CHECK constraint
```
{
  "name": "mmddyyy_migration_name",
  "operation": "add_check_constraint",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
    "condition": "check condition"
  },
  "functions": {
    up: "SQL function to transfer data from old version of column",
    down: "SQL function to transfer data from new version of column"
  }
}
```

#### Drop column
```
{
  "name": "mmddyyy_migration_name",
  "operation": "drop_column",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
  }
}
```

### Change data type
```
{
  "name": "mmddyyy_migration_name",
  "operation": "change_column_type",
  "info": {
    "schema": "schema_name",
    "table": "table_name",
    "column": "column_name",
    "type": "new_column_type"
  },
  "functions": {
    up: "SQL function to transfer data from old version of column",
    down: "SQL function to transfer data from new version of column"
  }
}
```
