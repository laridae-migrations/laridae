# frozen_string_literal: true

require 'pg'

# Connection to a PG database
class DatabaseConnection
  def initialize(database_hash)
    @database = PG.connect(database_hash)
    initial_config
  end

  def initial_config
    @database.exec_params('SET LOCK_TIMEOUT TO 1000;') # 1 second lock timeout
    @database.exec('SET client_min_messages TO WARNING;') # turn off notices
  end

  def query(sql, *params)
    @database.exec('BEGIN;')
    @database.exec_params(sql, *params)
    @database.exec('COMMIT;')
  rescue PG::LockNotAvailable => e
    puts "Lock acquisition timed out: #{e.message}"
    @database.exec('ROLLBACK;')
    sleep(1) # 1 second
    retry
  end

  def turn_off_notices
    @database.exec('SET client_min_messages TO WARNING;')
  end

  def close
    @database&.close
  end
end
