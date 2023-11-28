# rubocop:disable allcops
require 'pg'
BATCH_SIZE = 10000

# Calculate total time to run all statements
# Calcualte total exlusive lock time
# Also output lock time in chuncks 
def exec_time(db_conn, test_name, statements)
  total_exec_time = 0
  total_lock_time = 0

  min_backfill_time = 100000
  max_backfill_time = 0
  total_backfill_time = 0
  backfill_transaction_count = 0

  statements.each do |statement|
    start_time = Time.now

    db_conn.exec_params(statement)

    end_time = Time.now

    query_pid = db_conn.backend_pid
    locks_sql = <<~SQL
      SELECT transactionid, mode, virtualxid
      FROM pg_locks 
      WHERE pid = $1 AND granted = true AND mode = 'ExclusiveLock'
    SQL
    locks_result = db_conn.exec_params(locks_sql, [query_pid])
    
    statement_time = end_time - start_time
    total_exec_time += statement_time

    if locks_result.any?
      lock = locks_result.first
      total_lock_time += statement_time if lock['mode'] == 'ExclusiveLock'

      # puts "locking for #{statement}"
      # if statement.match('UPDATE')
        # backfill_transaction_count += 1
        # min_backfill_time = statement_time if statement_time < min_backfill_time
        # max_backfill_time = statement_time if statement_time > max_backfill_time
        # total_backfill_time += statement_time
      # end 
      #   puts "Virtual XID ID: #{lock['virtualxid']}"
      #   puts "Mode: #{lock['mode']}"
      #   puts "Transaction lock time: #{(statement_time* 1000).round(2)} milliseconds"
      #   puts "-----------------------"
      # end
    end
  end

  puts "Testing for: #{test_name}"
  puts "Total time: #{(total_exec_time * 1000).round(2)} milliseconds"
  puts "Total locks time: #{(total_lock_time * 1000).round(2)} milliseconds"
  # puts "Min backfill time: #{(min_backfill_time * 1000).round(2)} milliseconds"
  # puts "Max backfill time: #{(max_backfill_time * 1000).round(2)} milliseconds"
  # puts "Backfill transaction count: #{backfill_transaction_count}"
  # puts "Average backfill time: #{(total_backfill_time / backfill_transaction_count * 1000).round(2)} milliseconds"
end

# CREATING TABLE
# ====================================
# create test table with id and username
def create_table_sql
  # <<~SQL
  #   DROP TABLE IF EXISTS load_test;
  #   CREATE TABLE load_test (
  #     id serial PRIMARY KEY, 
  #     username text
  #   );
  # SQL
  <<~SQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    DROP TABLE IF EXISTS load_test_uuid;
    CREATE TABLE load_test_uuid (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      username TEXT
   );
  SQL
end

def insert_ids(testing_size)
  db_url = "postgresql://postgres:postgres@localhost:5432/test_env"
  db_conn = PG.connect(db_url)
  db_conn.exec_params('SET client_min_messages TO WARNING;')
  db_conn.exec_params(create_table_sql)
  db_conn.exec_params(insert_id_only_sql(1, testing_size))
ensure
  db_conn&.close
end

# insert into test table with id from start to end (lockable)
def insert_id_only_sql(start_count, end_count)
  <<~SQL
    INSERT INTO load_test (id)
    SELECT generate_series(#{start_count}, #{end_count});
  SQL
end


# ====================================

def backfill_no_batching
  <<~SQL
    UPDATE load_test
    SET username = concat('Name_', md5(random()::text));
  SQL
end

# add not null constraint to username column (lockable)
def alter_table_add_not_null_sql
  <<~SQL
    ALTER TABLE load_test
    ALTER COLUMN username SET NOT NULL;
  SQL
end

# add not null constraint to username column not valid (lock free)
def alter_table_add_not_null_not_valid_sql
  <<~SQL
    ALTER TABLE load_test
    ADD CONSTRAINT username_not_null 
      CHECK (username IS NOT NULL) NOT VALID;
  SQL
end

def batch_backfill_sql(total_rows)
  (0..total_rows).step(BATCH_SIZE).map do |offset|
    <<~SQL
      UPDATE load_test
      SET username = concat('Name_', md5(random()::text))
      FROM (
        SELECT id
        FROM load_test
        ORDER BY id
        LIMIT #{BATCH_SIZE} OFFSET #{offset}
      ) AS sub_table
      WHERE load_test.id = sub_table.id;
    SQL
  end
end

def validate_add_not_null
  <<~SQL
    ALTER TABLE load_test
    VALIDATE CONSTRAINT username_not_null;
  SQL
end



def test_locking(testing_size)
  db_url = "postgresql://postgres:postgres@localhost:5432/test_env"
  db_conn = PG.connect(db_url)
  db_conn.exec_params('SET client_min_messages TO WARNING;')

  statements = [
    # backfill_no_batching, 
    alter_table_add_not_null_sql
  ].flatten

  exec_time(db_conn, "Add not null #{testing_size} rows lockable", statements)
ensure 
  db_conn&.close
end

def test_no_locking(testing_size)
  db_url = "postgresql://postgres:postgres@localhost:5432/test_env"
  db_conn = PG.connect(db_url)
  db_conn.exec_params('SET client_min_messages TO WARNING;')

  statements = [
    alter_table_add_not_null_not_valid_sql, 
    batch_backfill_sql(testing_size),
    validate_add_not_null
  ].flatten

  exec_time(db_conn, "Add not null #{testing_size} rows non-locking", statements)
ensure 
  db_conn&.close
end

testing_size = 10**5
insert_ids(testing_size)

# puts "============================"
# test_locking(testing_size)
# puts "============================"
# test_no_locking(testing_size)
# puts "============================"
