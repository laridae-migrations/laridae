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
  operation: "set_unique",
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
  operation: "set_foreign_key",
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
