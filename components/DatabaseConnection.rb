# frozen_string_literal: true

require 'pg'

# Connection to a PG database
class DatabaseConnection
  def initialize(db_url)
    @database = PG.connect(db_url)
    initial_config
  end

  def initial_config
    @database.exec_params('SET LOCK_TIMEOUT TO 1000;') # 1 second lock timeout
    @database.exec_params('SET client_min_messages TO WARNING;') # turn off notices
  end

  def query(sql, *params)
    @database.exec('BEGIN;')
    result = @database.exec_params(sql, *params)
    @database.exec('COMMIT;')
    result
  rescue PG::LockNotAvailable => e
    puts "Lock acquisition timed out: #{e.message}"
    @database.exec('ROLLBACK;')
    sleep(1) # 1 second
    retry
  end

  def close
    @database&.close
  end
end