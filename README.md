<div align="center">
  <img width="250" src="https://i.ibb.co/fHTwF2T/Original-Logo.png" alt="Laridae Original Logo">
</div>

# LARIDAE - Zero-downtime, reversible, schema migrations tool for PostgreSQL with automated integration into GitHub Action workflow

`Laridae` _(LAR-i-dae)_ is an open-source tool that enables reversible, zero-downtime schema migrations in PostgreSQL, synchronizing them with application code deployments for apps using ECS Fargate. It allows application instances expecting the pre-migration and post-migration schema to use the same database simultaneously without requiring changes to either version's code. Additionally, recent schema migrations can be reversed without data loss. This is accomplished with minimal interference with usual reads and writes to the database.

**This repository only contains the code for the core functionality of schema migration**. When used alone, this repository acts as a Command-Line tool to facilitate zero-downtime, minimal-locking database changes. `Laridae` core tool allows both new and old applications code to work simultaneously on the same database, as well as the ability to rollback schema changes.

The accompanying repositories with the necessary codes for the pipeline integration can be found at: 

- [Laridae GitHub Action](https://github.com/laridae-migrations/laridae-action)
- [Laridae Pipeline Initialization Script](https://github.com/laridae-migrations/laridae-initialization)

## Table of Contents
- [Installation](#installation)
- [Suported Migrations](#supported-migrations)
- [Migration file](#Migration-file)

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
- Rename a column
- Add a not-null constraint to an existing column
- Add a unique constraint to an existing column
- Add check constraint to an existing column
- Drop a column
- Change a column data type

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

- Rename a column
- Add a not-null constraint to an existing column
- Add a unique constraint to an existing column
- Add check constraint to an existing column
- Drop a column
- Change a column data type

## CLI

To use the cli, first run
`./laridae init [DATABASE URL]`

Then, to expand, run
`./laridae expand [migration script filepath]`

It outputs the URL where the new schema is available.

To contract, completing the migration, run
`./laridae contract`

To reverse the changes done in the expand phase, run
`./laridae rollback`

Only one migration in a given database may be run at a time.

## TERRAFORM AND AWS CLI
Terraform modules are stored in `/terraform_modules`
The `initialization.tf` is a terraform file to set up a migration task
To run this terraform file, make sure to cd into `/terraform_modules` or wherever the `.tf` file(s) reside in: 
```
terraform init
terraform apply
```

The `env_override.json` file contains the `environment` variable that is used to specify the laridae command to use. For example:
```json
{
  "containerOverrides": [{
    "name": "laridae_migration_task",
    "environment": [
      {
        "name": "ACTION",
        "value": "init"
      }
    ]
  }]
}
```

To run this task that Terraform sets up, from the AWS CLI, run:
```
aws ecs run-task `
  --cluster hr-app-cluster `
  --task-definition laridae_migration_task_definition `
  --launch-type FARGATE `
  --network-configuration 'awsvpcConfiguration={subnets=[subnet-03a332974d1a8ae54],securityGroups=[sg-0662da6c515199370],assignPublicIp=ENABLED}' `
  --overrides file://env_override.json
```

## ABOUT THE PROJECT DIRECTORIES

- `components`: contains `DatabaseConnection.rb`, `MigrationExecutor.rb`, `TableManipulator.rb`, and `MigrationRecordkeeper.rb`.
- `examples`: specific examples using the `HR_app` example app
- `operations`: each file contains the definition of a Ruby class responsible for a specific operation

## `DatabaseConnection.rb`

This class represents the connection to the PostgreSQL database.

To instantiate a `DatabaseConnection` object, pass in a hash containing the database connection parameters. [A list of valid parameters](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS) can be found in the PostgreSQL documentations.

Automatic configurations for each connection at initialization include:
- Sets `lock_timeout` to 1 second
- Turns of psql message logging

Example:

```ruby
DatabaseConnection.new(
  {
    dbname: 'postgres',
    host: 'localhost',
    port: 5432,
    user: 'postgres'
  }
)
```

## `CommandLineInterface.rb`

This class deals with tasks specific to the command-line interface for laridae: parsing the user's command-line arguments, storing and accessing the database URL in a file, parsing the JSON of the migration script into a Ruby hash, and prompting the user to choose actions during the migration.

Its initializer takes an array containing the command-line arguments to parse.

## `EnvironmentVariablesInterface.rb`

This class presents an alternative interface for laridae in which all the necessary inputs are provided through environment variables. It is intended to be used in setting like an ECS container or Lambda.

Its initializer takes no arguments. The necessary environment variables are `DATABASE_URL`, `ACTION`, which is one of `init`, `expand`, `rollback`, or `contract`, and, if the action is `expand`, `SCRIPT`, containing the migration script JSON.

## `MigrationExecutor.rb`

This class is responsible for orchestrating the migration at a high-level by delegating the individual migration steps to appropriate classes.

Its initializer takes a database URL or database connection hash as described above for `DatabaseConnection.rb`.

## `TableManipulator.rb`

This class contains logic for interacting directly with the database that is used by various operations: some of these tasks are specific to expand-and-contract, like creating triggers and backfilling, whereas others are common database operations like adding a constraint or dropping a column.

To create a TableManipulator, pass in a `DatabaseConnectionObject` and strings containing the schema and table name it will operate on.

## `MigrationRecordkeeper.rb`

This class is responsible for keeping track of the currently open migration. It stores the migration script for the open migration in the table "laridae.open_migration" and exposes methods for creating/reading/removing an open migration.

Its initializer takes a `DatabaseConnectionObject` for the database where the migration info should be stored.

## SCRIPT VALIDATOR

This class contains initial checks on the json migration script to vet out any glarring conflicts such as: invalid schema / table / column name, column is a Primary Key, or referenced

The `Validator` class can be run directly, requiring a `DatabaseConnection` object, and a migration script hash

```ruby
Validator.new(db_connection, script_migration).run
```

A valid migration will return:

```ruby
{ 'valid' => true }
```

A migration script containing error will return a hash object similar to:

```ruby
{ 'valid' => false,
  'message' => 'Some error message' }
```

## OPERATIONS

The details of performing expand/contract/rollback for each operation are the responsibility of classes defined in the operations directory. Each of these classes takes a `DatabaseConnection` object, and a `migration_script` hash containing the necessary data for the migration. They expose `expand`, `contract`, and `rollback` methods for performing those actions for the supplied migration script.

Example migration scripts:

```json
{
  "operation": "add_not_null",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone"
  },
  "functions": {
    "up": "CASE WHEN phone IS NULL THEN '0000000000' ELSE phone END",
    "down": "phone"
  }
}
```

```json
{
  "operation": "rename_column",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone",
    "new_name": "phone_number"
  }
}
```

```json
{
  "operation": "add_check_constraint",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone",
    "condition": "phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d'"
  },
  "functions": {
    "up": "CASE WHEN (NOT phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d') THEN '000-000-0000' ELSE phone END",
    "down": "phone"
  }
}
```

```json
{
  "operation": "drop_column",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone"
  }
}
```

```json
{
  "operation": "create_index",
  "info": {
    "schema": "public",
    "table": "employees",
    "column": "phone",
    "method": "btree"
  }
}
```

# - adding a new column to a table that is nullable (can have null values)

```ruby
test_add_column_script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "description",
      type: "text",
      nullable: true,
    },
  }
}
```

# - adding a new column to a table with a not null constraint

```ruby
test_add_column_script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "description",
      type: "text",
      nullable: true,
    },
  }
}
```

# - adding a new column to a table with a unique constraint

```ruby
test_add_column_script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "computer_id",
      type: "integer",
      unique: true,
    },
  }
}
```

# adding a new column with a check constraint

```ruby
test_add_column_script = {
  operation: "add_column",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "age_insert_ex",
      type: "integer",
      check: {
        name: "age_check",
        constraint: "age >= 18"
      }
    },
  }
}
```

# setting a unique constraint on a column in a table

Note functions are WRONG and DO NOT work

```ruby
test_add_column_script = {
  operation: "add_unique_constraint",
  info: {
    schema: "public",
    table: "employees",
    column: {
      name: "computer_id",
    },
  },
  functions: {
    up: "CASE WHEN computer_id IS NOT UNIQUE THEN '0000000000' ELSE phone END",
    down: "computer_id"
  }
}
```

# adding a foreign key to column

```ruby
test_add_column_script = {
  operation: "add_foreign_key_constraint",
  info: {
    schema: "public",
    table: "phones_ex",
    column: {
      name: "employee_id",
      references: {
        name: "fk_employee_id",
        table: "employees",
        column: "id",
      },
    },
  },
  functions: {
    up: "(SELECT CASE WHEN EXISTS (SELECT 1 FROM employees WHERE employees.id = employee_id) THEN employee_id ELSE NULL END)",
    down: "employee_id"
  }
}
```

## SPECIFIC EXAMPLES

## TESTING

Testing is done using `rspec`, all specs can be found in `\tests`
`\test_data` contain `.pglsql` data for spec files, each spec handles its own data population

To run a spec:

```
rspec tests/spec_file_name.rb
```
