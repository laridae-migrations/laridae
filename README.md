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

## OPERATIONS

### `AddNotNull.rb`
To instantiate a `AddNotNull` object, pass in a `DatabaseConnection` object, and a `migration_script` hash containing the direction for the migration. 

Example migration script: 
```ruby 
{
  info: {
    schema: "public",
    table: "employees",
    column: "phone"
  },
  functions: {
    up: "SELECT CASE WHEN $1 IS NULL THEN ''0000000000'' ELSE $1 END",
    down: 'SELECT $1'
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
