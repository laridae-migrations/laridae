require "pg"

# Connection to a PG database
class DatabaseConnection
  def initialize(database_hash)
    # database_hash can contain: host, port, options, tty, dbname, login, password
    @database = PG.connect(database_hash)
  end

  def query(sql, *params) 
    puts("----------------", sql)
    @database.exec_params(sql, *params)
  end
end