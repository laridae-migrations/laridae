require "pg"

# Connection to a PG database
class DatabaseConnection
  def initialize(database_hash)
    # database_hash can contain: host, port, options, tty, dbname, login, password
    @database = PG.connect(database_hash)
  end

  def query(sql, *params)
    @database.exec_params(sql, *params)
  end

  def turn_off_notices
    @database.exec("SET client_min_messages TO WARNING;")
  end

  def close
    @database.close if @database
  end
end