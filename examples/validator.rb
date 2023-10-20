# rubocop:disable all

require 'json'
require_relative '../components/Validator'

def validate_add_check_constraint
  script_hash = JSON.parse({
    operation: 'add_check_constraint',
    info: {
      schema: 'public',
      table: 'employees',
      column: 'phone',
      condition: "phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d'"
    },
    functions: {
      up: "CASE WHEN (NOT phone ~* '\\d\\d\\d-\\d\\d\\d-\\d\\d\\d\\d') THEN '000-000-0000' ELSE phone END",
      down: 'phone'
    }
  }.to_json)

  db = DatabaseConnection.new(
    {
      dbname: 'human_resources',
      host: 'localhost',
      port: 5432,
      user: 'postgres'
    }
  )

  Validator.run(db, script_hash)
end

def validate_add_not_null
  script_hash = JSON.parse({
    operation: 'add_not_null',
    info: {
      schema: 'public',
      table: 'employees',
      column: 'phone'
    },
    functions: {
      up: "CASE WHEN phone IS NULL THEN '0000000000' ELSE phone END",
      down: 'phone'
    }
  }.to_json)

  db = DatabaseConnection.new(
    {
      dbname: 'human_resources',
      host: 'localhost',
      port: 5432,
      user: 'postgres'
    }
  )

  Validator.run(db, script_hash)
end

def validate_drop_column
  script_hash = JSON.parse({
    operation: 'drop_column',
    info: {
      schema: 'public',
      table: 'employees',
      column: 'phone'
    }
  }.to_json)

  db = DatabaseConnection.new(
    {
      dbname: 'human_resources',
      host: 'localhost',
      port: 5432,
      user: 'postgres'
    }
  )

  Validator.run(db, script_hash)
end

def validate_rename_column
  script_hash = JSON.parse({
    operation: 'rename_column',
    info: {
      schema: 'public',
      table: 'employees',
      column: 'phone',
      new_name: 'phone_numer'
    }
  }.to_json)

  db = DatabaseConnection.new(
    {
      dbname: 'human_resources',
      host: 'localhost',
      port: 5432,
      user: 'postgres'
    }
  )

  Validator.run(db, script_hash)
end

def validate_create_index
  script_hash = JSON.parse({
    operation: "create_index",
    info: {
      schema: "public",
      table: "employees",
      column: "age",
      method: "btree"
    },
  }.to_json)

  db = DatabaseConnection.new(
    {
      dbname: 'human_resources',
      host: 'localhost',
      port: 5432,
      user: 'postgres'
    }
  )

  Validator.run(db, script_hash)
end

# p validate_add_check_constraint
# p validate_add_not_null
# p validate_drop_column
# p validate_rename_column
p validate_create_index
