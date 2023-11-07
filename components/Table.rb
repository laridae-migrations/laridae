# frozen_string_literal: true

BATCH_SIZE = 1000

# rubocop:disable Metrics/ClassLength
# handles operation on 1 specific table
class Table
  attr_reader :schema, :name

  def initialize(db_conn, schema, table)
    @db_conn = db_conn
    @schema = schema
    @name = table
  end

  def create_new_version_of_column(old_column)
    sql = <<~SQL
      ALTER TABLE #{@schema}.#{@name}
      ADD laridae_new_#{old_column} #{column_type(old_column)}
    SQL
    @db_conn.query(sql)
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

  def column_type(column_name)
    sql = <<~SQL
      SELECT data_type FROM information_schema.columns
      WHERE table_schema = $1#{' '}
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
      WHERE c.constraint_schema = '#{@schema}'
        AND t.table_name = '#{@name}'
        AND t.constraint_type = 'PRIMARY KEY';
    SQL
    @db_conn.query(sql).first['column_name']
  end

  def total_rows_count
    sql = "SELECT COUNT(*) FROM #{@schema}.#{@name};"
    @db_conn.query(sql).first['count'].to_i
  end

  # rubocop:disable Metrics/MethodLength
  def backfill(new_column, up)
    pkey_column = primary_key_column

    (0..total_rows_count).step(BATCH_SIZE) do |offset|
      sql = <<~SQL
        WITH rows AS#{' '}
          (SELECT #{pkey_column} FROM #{@name} ORDER BY #{pkey_column}#{' '}
           LIMIT #{BATCH_SIZE} OFFSET #{offset})
        UPDATE #{@name} SET #{new_column} = #{up}
        WHERE EXISTS#{' '}
          (SELECT * FROM rows WHERE #{@name}.#{pkey_column} = rows.#{pkey_column});
      SQL

      @db_conn.query(sql)
    end
  end
  # rubocop:enable Metrics/MethodLength
end
