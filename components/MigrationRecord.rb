# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength

require 'json'

# This takes care of record keeping operations in laridae schema
# This class does not create its own database connection
# This class will never overwrite its data
class MigrationRecord
  def initialize(database_connection)
    @db_conn = database_connection
  end

  #=================================
  # METHODS TO CREATE + CHECK laridae SCHEMA, RELATION, ROW
  def initialize_laridae
    create_laridae_schema
    create_migrations_table
  end

  # only creates if not already exists
  def create_migrations_table
    sql = <<~SQL
      CREATE TABLE IF NOT EXISTS laridae.migrations (
        id serial PRIMARY KEY,
        name text NOT NULL,#{' '}
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        script JSONB NOT NULL,
        status TEXT CHECK (status IN ('expanded', 'contracted', 'rolled_back', 'aborted'))
      );
    SQL
    @db_conn.query(sql)
  end

  # only creates if not already exists
  def create_laridae_schema
    if laridae_exists?
      puts 'Laridae has been previously initialized in this database.'
    else
      sql = 'CREATE SCHEMA laridae;'
      @db_conn.query(sql)
      puts 'Laridae schema created.'
    end
  end

  def laridae_exists?
    sql = <<~SQL
      SELECT schema_name
      FROM information_schema.schemata
      WHERE schema_name = 'laridae';
    SQL
    @db_conn.query(sql).ntuples.positive?
  end

  #=================================
  # METHODS TO CHECK IF ACTION IS ALLOWED ON CURRENT DATABASE
  def ok_to_expand?(script)
    (!duplicated_migration?(script) && !last_migration_expanded?) || last_migration_aborted?
  end

  def ok_to_contract?
    last_migration_expanded?
  end

  def ok_to_rollback?
    last_migration_expanded?
  end

  def ok_to_restore?
    last_migration_aborted?
  end

  def duplicated_migration?(script)
    last_migration && script['name'] == last_migration['name'] && !last_migration['status'] == 'rolled_back'
  end

  def last_migration_expanded?
    last_migration && last_migration['status'] == 'expanded'
  end

  def last_migration_aborted?
    last_migration && last_migration['status'] == 'aborted'
  end

  #=================================
  # METHODS TO DOCUMENT MIGRATION STATUS
  def mark_expand_starts(script)
    create_new_migration(script)
    puts 'Starting new migration'
  end

  def mark_contract_starts
    mark_last_migration_aborted
  end

  def mark_rollback_starts
    mark_last_migration_aborted
  end

  def mark_last_migration_aborted
    sql = <<~SQL
      UPDATE laridae.migrations
      SET status = 'aborted'
      WHERE id = (SELECT id FROM laridae.migrations ORDER BY id DESC LIMIT 1);
    SQL
    @db_conn.query(sql)
  end

  def mark_expand_finishes(script)
    sql = <<~SQL
      UPDATE laridae.migrations
      SET status = 'expanded'
      WHERE id = (
        SELECT id FROM laridae.migrations#{' '}
        WHERE name = $1
        ORDER BY id DESC LIMIT 1
      );
    SQL
    @db_conn.query(sql, [script['name']])
  end

  def mark_contract_finishes
    sql = <<~SQL
      UPDATE laridae.migrations
      SET status = 'contracted'
      WHERE id = (SELECT id FROM laridae.migrations ORDER BY id DESC LIMIT 1);
    SQL
    @db_conn.query(sql)
  end

  def mark_rollback_finishes
    sql = <<~SQL
      UPDATE laridae.migrations
      SET status = 'rolled_back'
      WHERE id = (SELECT id FROM laridae.migrations ORDER BY id DESC LIMIT 1);
    SQL
    @db_conn.query(sql)
  end

  def create_new_migration(script)
    migration_name = script['name']
    json_script = script.to_json

    sql = <<~SQL
      INSERT INTO laridae.migrations (name, script, status)
      VALUES ($1, $2, $3)
    SQL
    @db_conn.query(sql, [migration_name, json_script, 'aborted'])
  end

  #=================================
  # METHODS TO FETCH MIGRATION DATA
  def last_migration
    sql = <<~SQL
      SELECT name, status, script FROM laridae.migrations
      ORDER BY id DESC LIMIT 1
    SQL
    result = @db_conn.query(sql)
    result.ntuples.zero? ? nil : result.first
  end
end
