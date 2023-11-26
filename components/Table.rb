# frozen_string_literal: true

BATCH_SIZE = 1000

require_relative './ConstraintPropagation'

# rubocop:disable Metrics/ClassLength
# handles operation on 1 specific table
class Table
  attr_reader :schema, :name

  def initialize(db_conn, schema, table)
    @db_conn = db_conn
    @schema = schema
    @name = table
  end

  def add_unique_column_sql(new_column, data_type, default_value)
    if default_value.nil?
      sql = <<~SQL
        ALTER TABLE #{@schema}.#{@name} ADD COLUMN #{new_column} #{data_type} UNIQUE;
      SQL
    else
      sql = <<~SQL
        ALTER TABLE #{@schema}.#{@name} ADD COLUMN #{new_column} #{data_type} DEFAULT #{default_value} UNIQUE;
      SQL
    end
    @db_conn.query(sql)
  end

  def add_column_sql(new_column, data_type, default_value)
    if default_value.nil?
      sql = "ALTER TABLE #{@schema}.#{@name} ADD COLUMN #{new_column} #{data_type};"
    else
      sql = <<~SQL
        ALTER TABLE #{@schema}.#{@name} ADD COLUMN #{new_column} #{data_type} DEFAULT #{default_value};
      SQL
    end
    @db_conn.query(sql)
  end

  def add_column(new_column, data_type, default_value, is_unique)
    if is_unique
      add_unique_column_sql(new_column, data_type, default_value)
    else
      add_column_sql(new_column, data_type, default_value)
    end
  end

  def create_new_version_of_column(old_column)
    new_column = "laridae_new_#{old_column}"
    data_type = column_type(old_column)
    is_unique = has_unique_constraint?(old_column)
    default_value = get_column_default_value(old_column)
    add_column(new_column, data_type, default_value, is_unique)

    return unless has_constraints?(old_column)

    ConstraintPropagation.new(@db_conn).duplicate_constraints(@name, old_column)
  end

  def has_constraints?(column)
    constraints = get_existing_constraints(column)
    !constraints.empty?
  end

  def drop_column(column_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}
      DROP COLUMN IF EXISTS #{column_name} CASCADE;
    SQL
    @db_conn.query(sql)
  end

  def rename_column(old_name, new_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}
      RENAME COLUMN #{old_name} TO #{new_name};
    SQL
    @db_conn.query(sql)
  end

  def add_constraint(constraint_name, constraint)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}
      ADD CONSTRAINT #{constraint_name} #{constraint};
    SQL
    @db_conn.query(sql)
  end

  def remove_constraint(constraint_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}
      DROP CONSTRAINT IF EXISTS #{constraint_name};
    SQL
    @db_conn.query(sql)
  end

  def rename_constraint(old_name, new_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}
      RENAME CONSTRAINT #{old_name} TO #{new_name};
    SQL
    @db_conn.query(sql)
  end

  def add_unique_index(index_name, table_name, column_name)
    sql = <<~SQL
      CREATE UNIQUE INDEX CONCURRENTLY #{index_name}
      ON #{@schema}.#{table_name} (#{column_name});
    SQL
    @db_conn.query_lockable(sql)
  end

  def add_unique_constraint(table_name, constraint_name, index_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{table_name}
      ADD CONSTRAINT #{constraint_name} UNIQUE
      USING INDEX #{index_name};
    SQL
    @db_conn.query(sql)
  end

  def validate_constraint(constraint_name)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}#{' '}
      VALIDATE CONSTRAINT #{constraint_name}
    SQL
    @db_conn.query(sql)
  end

  def column_type(column_name)
    sql = <<~SQL
      SELECT data_type FROM information_schema.columns
      WHERE table_schema = $1
        AND table_name = $2
        AND column_name = $3;
    SQL
    @db_conn.query(sql, [@schema, @name, column_name])
            .map { |tuple| tuple['data_type'] }
            .first
  end

  def all_columns_names
    sql = <<~SQL
      SELECT column_name
      FROM information_schema.columns
      WHERE table_schema = $1 and table_name = $2;
    SQL
    result = @db_conn.query(sql, [@schema, @name])
    result.map { |line| line['column_name'] }
  end

  def sql_to_declare_variables
    sql = ''
    all_columns_names.each do |column|
      sql += "#{column} #{@schema}.#{@name}.#{column}%TYPE := NEW.#{column}; \n"
    end
    sql
  end

  def columns_in_view(view_hash)
    result = []
    all_columns_names.each do |name|
      if view_hash.key?(name)
        result.push("#{name} AS #{view_hash[name]}") unless view_hash[name].nil?
      else
        result.push(name)
      end
    end
    result
  end

  def primary_key_column
    sql = <<~SQL
      SELECT c.column_name
      FROM information_schema.key_column_usage AS c
        JOIN information_schema.table_constraints AS t
        ON t.constraint_name = c.constraint_name
      WHERE t.table_schema = $1
        AND t.table_name = $2
        AND t.constraint_type = 'PRIMARY KEY';
    SQL
    result = @db_conn.query(sql, [@schema, @name])
    result.ntuples.zero? ? nil : result.first['column_name']
  end

  def total_rows_count
    sql = "SELECT COUNT(*) FROM #{@schema}.#{@name};"
    @db_conn.query(sql).first['count'].to_i
  end

  def has_unique_constraint?(column)
    unique_constraints = get_unique_constraint_name(column)
    unique_constraints.num_tuples.positive?
  end

  def get_unique_constraint_name(column)
    sql = <<~SQL
      SELECT tc.CONSTRAINT_NAME
      FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc#{' '}
          inner join INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE cu#{' '}
              on cu.CONSTRAINT_NAME = tc.CONSTRAINT_NAME#{' '}
      where tc.CONSTRAINT_TYPE = 'UNIQUE'
        and tc.TABLE_SCHEMA = $1
        and tc.TABLE_NAME = $2
        and cu.COLUMN_NAME = $3
    SQL
    @db_conn.query(sql, [@schema, @name, column])
  end

  def get_existing_constraints(column)
    sql = <<~SQL
      SELECT constraint_name FROM information_schema.constraint_column_usage#{' '}
      WHERE table_schema = $1
      AND table_name = $2#{' '}
      AND column_name = $3;
    SQL
    constraints = @db_conn.query(sql, [@schema, @name, column])
    constraints.values
  end

  # rubocop:disable Metrics/MethodLength
  def get_column_default_value(column_name)
    sql = <<~SQL
      SELECT col.table_schema,
        col.table_name,
        col.column_name,
        col.column_default
      FROM information_schema.columns col
      WHERE col.column_default IS NOT NULL
        AND col.table_schema NOT IN('information_schema', 'pg_catalog')
        AND col.table_schema = $1
        AND col.table_name = $2
        AND col.column_name = $3;
    SQL
    result = @db_conn.query(sql, [@schema, @name, column_name])
    result.field_values('column_default').first
  end

  def get_constraint_pairs(old_column, new_column)
    previously_existing_constraints = get_existing_constraints(old_column)
    current_constraints = get_existing_constraints(new_column)
    constraints_to_be_renamed = []

    unless previously_existing_constraints.empty?
      previously_existing_constraints.each do |preexisting|
        prev_constraint = preexisting[0]
        current_constraints.each do |current|
          cur_constraint = current[0]
          constraints_to_be_renamed.push([cur_constraint, prev_constraint]) if cur_constraint.match?(prev_constraint)
        end
      end
    end
    constraints_to_be_renamed
  end

  def backfill(new_column, up)
    pkey_column = primary_key_column

    (0..total_rows_count).step(BATCH_SIZE) do |offset|
      sql = <<~SQL
        WITH rows AS#{' '}
          (SELECT #{pkey_column} FROM #{@schema}.#{@name} ORDER BY #{pkey_column}#{' '}
           LIMIT #{BATCH_SIZE} OFFSET #{offset})
        UPDATE #{@schema}.#{@name} SET #{new_column} = #{up}
        WHERE EXISTS#{' '}
          (SELECT * FROM rows WHERE #{@schema}.#{@name}.#{pkey_column} = rows.#{pkey_column});
      SQL
      @db_conn.query(sql)
    end
  end
  # rubocop:enable Metrics/MethodLength
end
