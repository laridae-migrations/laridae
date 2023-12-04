<div align="center">
  <img width="300" src="https://i.ibb.co/q7FMJ9p/Transparent-Logo.png" alt="Laridae-Logo" >
</div>

# LARIDAE - Zero-downtime, reversible, schema migrations tool for PostgreSQL with automated integration into GitHub Action workflow

`Laridae` _(LAR-i-dae)_ is an open-source tool that enables reversible, zero-downtime schema migrations in PostgreSQL, synchronizing them with application code deployments for apps using ECS Fargate. It allows application instances expecting the pre-migration and post-migration schema to use the same database simultaneously without requiring changes to either version's code. Additionally, recent schema migrations can be reversed without data loss. This is accomplished with minimal interference with usual reads and writes to the database.

**This repository only contains the code for the core functionality of schema migration**. When used alone, this repository acts as a Command-Line tool to facilitate zero-downtime, minimal-locking database changes. `Laridae` core tool allows both new and old applications code to work simultaneously on the same database, as well as the ability to rollback schema changes.

The accompanying repositories with the necessary codes for the pipeline integration can be found at: 

- [Laridae GitHub Action](https://github.com/laridae-migrations/laridae-action)
- [Laridae Pipeline Initialization Script](https://github.com/laridae-migrations/laridae-initialization)

## Table of Contents
- [Installation](#installation)
- [Run a Migration](#Run-a-Migration)
- [Suported Migrations](#supported-migrations)
- [Migration file](#Migration-file)
  - [Migration files syntax:](#Migration-files-syntax)

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

## Supported migrations 

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

## Migration file

`Laridae` requires a migration file, which contains the instructions for the schema migration. 
The migration file **must** be a `.json` file, written in JSON formatting. The location of this file does not matter, as long as the location is supplied to `Laridae` at the time of execution. 

All migration files are required to have a migration name, as specified in the `name` key. Migration in a database with a duplicated name with another already executed 

### Migration files syntax:

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

#### Add an index 
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

#### Add a foreign key
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
  }
}
```

#### Rename a column
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

#### Add Not-NULL constraint
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
    "up": "SQL's to consolidate existing NULL values",
    "down": "column_name"
  }
}
```

#### Add UNIQUE constraint
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
    "up": "SQL's to consolidate existing duplicated values",
    "down": "column_name"
  }
}
```

#### Add CHECK constraint
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
    "up": "SQL's to consolidate existing values that violate check constraint",
    "down": "column_name"
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

#### Change data type
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
    "up": "SQL's to consolidate existing values that violate new data type",
    "down": "column_name"
  }
}
```

- Change a column data type

## Run a Migration 


