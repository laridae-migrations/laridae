#  do we need to add not valid or just add it straight up? - can we add not valid to all ADD CONSTRAINT constraints?

class ConstraintPropagation
  def initialize(db_connection)
    @database = db_connection
  end

  def create_dump_file()
    #  run command line from within database, will create file in whatever directory its in
    database_name = @database.query("SELECT current_database()").values[0][0]
    command = "pg_dump --schema-only -d #{database_name} -f \"#{Dir.pwd}/dump_files/laridae_schema_info_dump.sql\""
    system(command)
  end

  def get_columns_constraint_names(table, column)
    sql = <<~SQL
      SELECT constraint_name FROM information_schema.constraint_column_usage WHERE table_name=$1 AND column_name=$2;
    SQL
    constraint_names = @database.query(sql, [table, column]).map { |obj| obj["constraint_name"]}
  end

  def get_constraint_info_from_dump_file(constraint_name, column)
    sql = File.open("#{Dir.pwd}/dump_files/laridae_schema_info_dump.sql").read
    statements = sql.split(";")

    constraint_info = statements.filter do |statement|
      statement.include?(constraint_name)
    end
    # transform statement with constraint info into a string, split string by new line chars, strip away leading spaces
    constraint_commands = constraint_info.join('').split("\n").map { |line| line.lstrip }

    constraint_commands.filter { |command| command.include?(column)}.last
  end

  def replace_columns_in_command(command, column)
    command.gsub(/\b#{column}\b(?! [a-zA-Z])/, "laridae_new_#{column}")
  end

  def rename_constraint_in_command(command, column)
    command_arr = command.split(' ')
    constraint_name = command_arr[1]
    name_arr = constraint_name.split('_')
    renamed_name_arr = name_arr.map do |n|
      if n == column 
        "laridae_new_#{column}"
      else
        n
      end
    end
    command_arr[1] = renamed_name_arr.join('_')
    command_arr[-1] = command_arr[-1].slice!(0..-2)
    command_arr.join(' ')
  end

  def get_constraint_commands(table, column)
    constraints = get_columns_constraint_names(table, column)
    sql_commands = []
    constraints.each do |constraint| 
      command = get_constraint_info_from_dump_file(constraint, column)
      command = replace_columns_in_command(command, column)
      sql_commands.push(command)
    end
    sql_commands
  end

  def duplicate_constraints(table, column)
    create_dump_file()
    sql_commands = get_constraint_commands(table, column)
    sql_commands.each do |command|
      command = rename_constraint_in_command(command, column)
      if command.match?('UNIQUE')
        next
      end
      full_command = "ALTER TABLE #{table} ADD " + command
      puts full_command
      @database.query(full_command)
    end
  end
end

