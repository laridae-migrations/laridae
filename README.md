# LARIDAE

## ABOUT THE PROJECT DIRECTORIES

- `components`: contains `DatabaseConnection.rb`
- `examples`: specific examples using the `HR_app` example app
- `operations`: each file contains the definition of a Ruby Class that does a specific operation

## `DatabaseConnection.rb`

This Class represents the connection to the PostgreSQL database.

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

## SCRIPT VALIDATOR
Laridae will be configured to run an initial validation check on the migration script and the database. This checks for the valid existence of the entities involved in the migration

The `Validator` class can be run directly, requiring a `DatabaseConnection` object, and a migration script hash
```ruby
Validator.new(db_connection, script_migration).run
```

A valid migration will return a hash `{ valid: true }`
A migration script containing error will return a hash"
`{ valid: false, message: 'Some error message' }`

## OPERATIONS

### `AddNotNull.rb`

To instantiate a `AddNotNull` object, pass in a `DatabaseConnection` object, and a `migration_script` hash containing the direction for the migration.

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

## TESTING

Testing is done using `rspec`, all specs can be found in `\tests`
`\test_data` contain `.pglsql` data for spec files, each spec handles its own data population

To run a spec:
```
rspec tests/spec_file_name.rb
```
