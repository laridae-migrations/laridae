# frozen_string_literal: true

# class to create necessary sql commands to apply constraints from one column to another
class ConstraintPropagation
  def initialize(db_connection)
    @database = db_connection
  end

  def create_dump_file
    command = "pg_dump --schema-only -d #{@database.url} -f \"#{Dir.pwd}/dump_files/laridae_schema_info_dump.sql\""
    system(command)
  end

  def get_columns_constraint_names(schema, table, column)
    sql = <<~SQL
      SELECT constraint_name FROM information_schema.constraint_column_usage WHERE table_name=$1 AND column_name=$2;
    SQL
    @database.query(sql, [table, column]).map { |obj| obj['constraint_name'] }
  end

  def get_constraint_info_from_dump_file(constraint_name, column)
    sql = File.open("#{Dir.pwd}/dump_files/laridae_schema_info_dump.sql").read
    statements = sql.split(';')

    constraint_info = statements.filter do |statement|
      statement.include?(constraint_name)
    end
    # transform statement with constraint info into a string, split string by new line chars, strip away leading spaces
    constraint_commands = constraint_info.join('').split("\n").map(&:lstrip)

    constraint_commands.filter { |command| command.include?(constraint_name) }.first
  end

  def replace_columns_in_command(command, column)
    command.gsub(/\b#{column}\b/, "laridae_new_#{column}")
  end

  def remove_trailing_char(text)
    text.slice!(0..-2)
  end

  def trailing_comma?(text)
    last_char = text.split('').last
    last_char == ','
  end

  def rename_constraint_in_command(command, column)
    command_arr = command.split(' ')
    constraint_name = command_arr[1]
    renamed_constraint_name = "laridae_new_#{constraint_name}"
    command_arr[1] = renamed_constraint_name
    command_arr[-1] = remove_trailing_char(command_arr[-1]) if trailing_comma?(command_arr[-1])
    command_arr.join(' ')
  end

  def get_constraint_commands(schema, table, column)
    constraints = get_columns_constraint_names(schema, table, column)
    sql_commands = []
    constraints.each do |constraint|
      command = get_constraint_info_from_dump_file(constraint, column)
      sql_commands.push(replace_columns_in_command(command, column))
    end
    sql_commands
  end

  def duplicate_constraints(schema, table, column)
    create_dump_file
    sql_commands = get_constraint_commands(schema, table, column)
    sql_commands.each do |command|
      command = rename_constraint_in_command(command, column)
      next if command.match?('UNIQUE')

      full_command = "ALTER TABLE #{schema}.#{table} ADD #{command} NOT VALID"
      @database.query(full_command)
    end
  end
end
