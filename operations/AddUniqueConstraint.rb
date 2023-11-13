# frozen_string_literal: true

require_relative './GeneralOperation'

class AddUniqueConstraint < GeneralOperation
  def initialize(db_conn, script)
    super
    @new_column = "laridae_new_#{@column}"
    @unique_constraint_name = "laridae_constraint_#{@column}_unique"
    @unique_index_name = "#{@olumn}_unique"
    @functions = script['functions']
  end

  def rollback
    super
    @table.drop_column(@new_column)
    @table.remove_constraint(@unique_constraint_name)
  end

  def expand
    before_view = { @new_column => nil }
    after_view = { @column['name'] => nil, @new_column => @column['name'] }
    super(before_view, after_view)

    @table.create_new_version_of_column(@column)
    @table.add_unique_index(@unique_index_name, @table.name, @new_column)
    @table.add_unique_constraint(@table.name, @unique_constraint_name, @unique_index_name)
    @table.backfill(@new_column, @functions['up'])
  end

  def contract
    super
    @table.drop_column(@column)
    @table.rename_column(@new_column, @column)
    new_constraint_name = "constraint_#{@column}_unique"
    @table.rename_constraint(@unique_constraint_name, new_constraint_name)
    # propagate_constraints
  end
end
