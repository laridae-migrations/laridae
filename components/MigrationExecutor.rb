require_relative './TableManipulator'
require_relative '../operations/AddNotNullHandler'
require 'json'

class MigrationExecutor
  HANDLERS_BY_OPERATION = {
    "add_not_null" => AddNotNullHandler
  }
  def initialize(db_connection, migration_script)
    @database = db_connection
    @database.turn_off_notices
    @script = JSON.parse(migration_script)
  end

  def run
    operation_name = @script["operation"]
    info = @script["info"]
    schema = info["schema"]
    table = info["table"]
    operation_handler = HANDLERS_BY_OPERATION[operation_name].new(@database, @script)
    puts "Should clean up be done on the database? (Y/N) "
    choice = gets.chomp.upcase
    operation_handler.rollback if choice == 'Y' 
 
    operation_handler.expand
    
    puts "Is it safe to contract? (Y/N) "
    choice = gets.chomp.upcase
    if choice == 'Y' 
      operation_handler.contract 
      puts 'Expand and Contract completed'
    else 
      puts 'Expand only'
    end
    @database.close
  end
end