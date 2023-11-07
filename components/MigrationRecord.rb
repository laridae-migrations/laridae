# frozen_string_literal: true

require 'json'

# This takes care of record keeping operations in laridae schema
# This class does not create its own database connection
# This class will never overwrite its data
class MigrationRecord
  def initialize(database_connection)
    @db_conn = database_connection
  end

  def initialize_laridae
    create_laridae_schema
    create_migrations_table
  end

  # create laridae schema if one does not already exist
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

  # create migrations table if one does not already exist
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

  # starts a new migration row if a new migration exists
  def mark_expand_starts(script)
    create_new_migration(script)
    puts 'Starting new migration'
  end

  def mark_contract_starts
    sql = <<~SQL
      UPDATE laridae.migrations
      SET status = 'aborted'
      WHERE id = (SELECT id FROM laridae.migrations ORDER BY id DESC LIMIT 1);
    SQL
    @db_conn.query(sql)
  end

  def ok_to_expand?(script)
    !duplicated_migration?(script) || last_migration_aborted?
  end

  def ok_to_contract?
    last_migration && last_migration_expanded?
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

  def duplicated_migration?(script)
    !last_migration.nil? && script['name'] == last_migration['name']
  end

  def last_migration_aborted?
    last_migration['status'] == 'aborted'
  end

  def last_migration_expanded?
    last_migration['status'] == 'expanded'
  end

  def last_migration
    sql = <<~SQL
      SELECT name, status, script FROM laridae.migrations
      ORDER BY id DESC LIMIT 1
    SQL
    result = @db_conn.query(sql)
    result.ntuples.zero? ? nil : result.first
  end

  # change status from aborted to expanded
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
end
