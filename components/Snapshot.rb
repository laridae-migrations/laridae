class ViewUpdateError < StandardError; end

class Snapshot
  def initialize(database, schema)
    @database = database
    @schema = schema
    @views = {}
  end

  def update_table_view(table, changes)
    if !@views.key?(table)
      @views[table] = {}
    end
    view = @views[table]
    changes.each do |physical_column, visible_column|
      if view.key?(physical_column)
        raise ViewUpdateError.new <<~HEREDOC.gsub(/\s+/, " ").strip
        Name of #{physical_column} in view #{@schema}.#{table} has already been
        assigned to #{view[physical_column]}; cannot reassign to #{visible_column}.
        HEREDOC
      end
      view[physical_column] = visible_column
    end
  end

  def create_view(table)
    table_manipulator = TableManipulator.new(@database, @schema, table)
    view = @views[table]
    columns_in_view = []
    TableManipulator.get_all_columns_names.each do |name|
      if view.key?(name)
        if view[name] != nil
          columns_in_view.push("#{name} AS #{view[name]}")
        end
      else
        columns_in_view.push(name)
      end
    end
    sql = <<~SQL
      CREATE SCHEMA #{schema};
      CREATE VIEW #{schema}.#{name} AS 
      SELECT #{columns_in_view.join(", ")} from #{@schema}.#{@table};
    SQL
    @database.query(sql)
  end

  def create
    views.each_key do |table|
      create_view(table)
    end
  end
end