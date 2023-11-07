# frozen_string_literal: true

require 'pg'

# Connection to a PG database
class DatabaseConnection
  def initialize(db_url)
    @db_conn = PG.connect(db_url)
    initial_config
  rescue PG::Error => e
    puts 'Cannot connect to database. '
  end

  def initial_config
    @db_conn.exec_params('SET LOCK_TIMEOUT TO 1000;') # 1 second lock timeout
    @db_conn.exec_params('SET client_min_messages TO WARNING;') # turn off notices
  end

  def query(sql, *params)
    @db_conn.exec('BEGIN;')
    result = @db_conn.exec_params(sql, *params)
    @db_conn.exec('COMMIT;')
    result
  rescue PG::LockNotAvailable => e
    puts "Lock acquisition timed out: #{e.message}"
    @db_conn.exec('ROLLBACK;')
    sleep(1) # 1 second
    retry
  end
  
  def query_lockable(sql, *params)
    @db_conn.exec_params(sql, *params)
  end

  def close
    @db_conn&.close
  end
end
