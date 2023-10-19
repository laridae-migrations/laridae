# LARIDAE

## ABOUT THE PROJECT DIRECTORIES

- `components`: contains `DatabaseConnection.rb`, `MigrationExecutor.rb`, and `TableManipulator.rb`
- `examples`: specific examples using the `HR_app` example app
- `operations`: each file contains the definition of a Ruby class responsible for a specific operation

## `DatabaseConnection.rb`

This class represents the connection to the PostgreSQL database.

To instantiate a `DatabaseConnection` object, pass in a hash containing the database connection parameters. [A list of valid parameters](https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS) can be found in the PostgreSQL documentations.

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

## `MigrationExecutor.rb`

This class is responsible for orchestrating the migration at a high-level: it deals with parsing the JSON of the migration script into a Ruby hash, prompting the user to choose actions throughout the migration, and delegating the individual migration steps to appropriate classes.

Its initializer takes two arguments, a `DatabaseConnection` object and a JSON object containing the migration script

## `TableManipulator.rb`

This class contains logic for interacting directly with the database that is used by various operations: some of these tasks are specific to expand-and-contract, like creating triggers and backfilling, whereas others are common database operations like adding a constraint or dropping a column.

To create a TableManipulator, pass in a `DatabaseConnectionObject` and strings containing the schema and table name it will operate on.

## OPERATIONS

The details of performing expand/contract/rollback for each operation are the responsibility of classes defined in the operations directory. Each of these classes takes a `DatabaseConnection` object, and a `migration_script` hash containing the necessary data for the migration.

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

Use the `#run` method to start the Expand and Contract process:

- User will be prompted whether to execute clean up, which clean up artifacts from any previously aborted `AddNotNull` runs
- User will be prompted to health check the database prior to the contract phase

## SPECIFIC EXAMPLES

### `add_not_null.rb`

A prototype of our functionality in a simple set use-case:

Adding the `NOT NULL` constraint to the `phone` column by:

- Create a column `phone_not_null` with the `NOT NULL` as a table constraint
- Create 2 views: `before` and `after`
- Add triggers to propagate data between `phone` and `phone_not_null` on inserts and updates
- Backfilling `phone_not_null` with `'0000000000'`
- Validate the table `NOT NULL` constraint
- Prompt the user whether or not to contract: delete all views, triggers, functions, delete `phone`, rename `phone_not_null` to `phone`
