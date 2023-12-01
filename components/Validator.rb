# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ClassLength
require_relative './DatabaseConnection'
require 'json'

# This class is meant to be run as class method
# such as Validator.run(db, script_location).run
# which will return an object validating the
# migration script is valid or not
# this class does not manage its own db connection
class Validator
  def self.run_with_location(db_connection, migration_file_location)
    @database = db_connection

    checks = [check_file_location_extension(migration_file_location)]

    if checks.first['valid']
      @script_hash = JSON.parse(File.read(migration_file_location))
      operation_name = @script_hash['operation']
      migration_name = @script_hash['name']

      checks += [check_operation_supported(operation_name), check_migration_name_exists(migration_name)]
      checks += send(operation_name) if respond_to?(operation_name)
    end

    checks.each do |check_result|
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  def self.run_with_script(db_connection, migration_script)
    @database = db_connection
    @script_hash = JSON.parse(migration_script)
    operation_name = @script_hash['operation']
    migration_name = @script_hash['name']

    checks = [check_operation_supported(operation_name), check_migration_name_exists(migration_name)]
    checks += send(operation_name) if respond_to?(operation_name)

    checks.each do |check_result|
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  #=======================================================
  # VALIDATOR METHODS CORRESPONDING ALL
  def self.check_file_location_extension(migration_file_location)
    if File.extname(migration_file_location) != '.json'
      { 'valid' => false, 'message' => 'Migration script does not have .json extension.' }
    elsif !File.exist?(migration_file_location)
      { 'valid' => false, 'message' => "Migration script #{migration_file_location} not found" }
    else
      { 'valid' => true }
    end
  end

  def self.check_operation_supported(operation_name)
    if operation_name.nil?
      { 'valid' => false, 'message' => 'Operation missing from migration script' }
    elsif !respond_to?(operation_name)
      { 'valid' => false, 'message' => 'Operation not supported' }
    else
      { 'valid' => true }
    end
  end

  def self.check_migration_name_exists(migration_name)
    if migration_name.nil?
      { 'valid' => false, 'message' => 'Migration name missing from migration script' }
    else
      { 'valid' => true }
    end
  end

  #=======================================================
  # VALIDATOR METHODS CORRESPONDING TO OPERATIONS
  def self.change_column_type
    [check_schema_table_column_exist,
     check_column_does_not_contain_unsupported_constraints]
  end

  def self.add_not_null_constraint
    [check_schema_table_column_exist,
     check_column_does_not_contain_unsupported_constraints]
  end

  def self.add_check_constraint
    [check_schema_table_column_exist,
     check_column_does_not_contain_unsupported_constraints]
  end

  def self.drop_column
    [check_schema_table_column_exist,
     check_column_does_not_contain_unsupported_constraints]
  end

  def self.rename_column
    schema = @script_hash['info']['schema']
    table = @script_hash['info']['table']
    new_name = @script_hash['info']['new_name']

    [check_schema_table_column_exist,
     check_name_valid(new_name),
     check_name_not_taken(schema, table, new_name),
     check_column_does_not_contain_unsupported_constraints]
  end

  def self.create_index
    [check_schema_table_column_exist]
  end

  def self.add_column
    schema = @script_hash['info']['schema']
    table = @script_hash['info']['table']
    new_name = @script_hash['info']['column']['name']

    [check_schema_table_column_exist,
     check_name_valid(new_name),
     check_name_not_taken(schema, table, new_name)]
  end

  def self.add_foreign_key_constraint
    schema = @script_hash['info']['schema']
    table = @script_hash['info']['table']
    column = @script_hash['info']['column']['name']

    [check_schema_exists(schema),
     check_table_exists(schema, table),
     check_column_exists(schema, table, column),
     check_column_does_not_contain_unsupported_constraints]
  end

  def self.add_unique_constraint
    [check_schema_table_column_exist,
     check_column_does_not_contain_unsupported_constraints,
     check_column_not_already_unique]
  end

  #=======================================================
  # Check if table, schema, column given in script_hash are valid
  def self.check_schema_table_column_exist
    schema = @script_hash['info']['schema']
    table = @script_hash['info']['table']
    column = @script_hash['info']['column']

    schema_check = check_schema_exists(schema)
    table_check = check_table_exists(schema, table)
    column_check = check_column_exists(schema, table, column)

    checks = [schema_check, table_check, column_check]

    checks.each do |check_result|
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  def self.check_schema_exists(schema)
    sql = <<~SQL
      SELECT schema_name FROM information_schema.schemata#{' '}
       WHERE schema_name = '#{schema}';
    SQL

    result = @database.query(sql)
    if result.num_tuples.zero?
      { 'valid' => false, 'message' => 'Schema does not exist' }
    else
      { 'valid' => true }
    end
  end

  def self.check_table_exists(schema, table)
    sql = <<~SQL
      SELECT table_name FROM information_schema.tables
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}';
    SQL

    result = @database.query(sql)
    if result.num_tuples.zero?
      { 'valid' => false, 'message' => 'Table does not exist' }

    else
      { 'valid' => true }
    end
  end

  def self.check_column_exists(schema, table, column)
    return { 'valid' => true } unless column.instance_of? String

    sql = <<~SQL
      SELECT column_name FROM information_schema.columns
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}'
        AND column_name = '#{column}';
    SQL

    result = @database.query(sql)
    if result.num_tuples.zero?
      { 'valid' => false, 'message' => 'Column does not exist' }
    else
      { 'valid' => true }
    end
  end

  #=======================================================
  # Check that the specified column is not a PRIMARY KEY
  # or is a reference to a FOREIGN KEY
  def self.check_column_does_not_contain_unsupported_constraints
    schema = @script_hash['info']['schema']
    table = @script_hash['info']['table']
    column = @script_hash['info']['column']

    checks = [check_column_is_not_primary_key(schema, table, column),
              check_column_is_not_fkey_reference(schema, table, column)]

    checks.each do |check_result|
      return check_result unless check_result['valid']
    end
    { 'valid' => true }
  end

  def self.check_column_is_not_primary_key(schema, table, column)
    sql = <<~SQL
      SELECT *
      FROM information_schema.key_column_usage AS c
        JOIN information_schema.table_constraints AS t
        ON t.constraint_name = c.constraint_name
      WHERE c.constraint_schema = '#{schema}'
        AND t.table_name = '#{table}'#{' '}
        AND c.column_name = '#{column}'
        AND t.constraint_type = 'PRIMARY KEY';
    SQL

    result = @database.query(sql)

    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'Column has a Primary Key constraint' }
    end
  end

  def self.check_column_is_not_fkey_reference(schema, table, column)
    sql = <<~SQL
      SELECT *#{' '}
      FROM pg_constraint c#{' '}
      WHERE c.confrelid = (SELECT oid FROM pg_class#{' '}
                            WHERE relnamespace = (SELECT oid FROM pg_namespace#{' '}
                                                    WHERE nspname = '#{schema}')#{' '}
                            AND relname = '#{table}')
            AND c.confkey @> (SELECT array_agg(attnum) FROM pg_attribute#{' '}
                              WHERE attname = '#{column}'#{' '}
                              AND attrelid = c.confrelid);
    SQL

    result = @database.query(sql)

    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'Column is referenced in a Foreign Key constraint' }
    end
  end

  def self.check_column_not_already_unique
    schema = @script_hash['info']['schema']
    table = @script_hash['info']['table']
    column = @script_hash['info']['column']

    sql = <<~SQL
      SELECT * FROM information_schema.table_constraints tc#{' '}
      INNER JOIN information_schema.constraint_column_usage cu#{' '}
        ON cu.constraint_name = tc.constraint_name#{' '}
      WHERE tc.constraint_type = 'UNIQUE'
        AND tc.table_name = $1
        AND cu.column_name = $2;
    SQL

    result = @database.query(sql, [table, column])
    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'Column already has a unique constraint' }
    end
  end

  #=======================================================
  # PostgreSQL column names only contains a-zA-Z0-9 and underscores(_), and cannot start with numbers
  def self.check_name_valid(name)
    if name.match(/[^0-9a-z_]/i)
      { 'valid' => false, 'message' => 'Name contain invalid character(s)' }
    elsif !name.match(/^[_a-z]/i)
      { 'valid' => false, 'message' => 'Name can only starts with alphabetical characters or underscore' }
    else
      { 'valid' => true }
    end
  end

  # check that there isn't already another column with the same name
  def self.check_name_not_taken(schema, table, new_column_name)
    sql = <<~SQL
      SELECT column_name FROM information_schema.columns
        WHERE table_schema = '#{schema}'
        AND table_name = '#{table}'
        AND column_name = '#{new_column_name}';
    SQL

    result = @database.query(sql)

    if result.num_tuples.zero?
      { 'valid' => true }
    else
      { 'valid' => false, 'message' => 'New column name already exists' }
    end
  end
end
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/ClassLength
