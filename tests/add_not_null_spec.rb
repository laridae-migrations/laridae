require 'json'
require_relative "../components/DatabaseConnection.rb"
require_relative "../operations/AddNotNull.rb"

RSpec.configure do |config| 
  
  config.before(:suite) do
    db = DatabaseConnection.new(
      {
        dbname: 'music',
        host: 'localhost',
        port: 5432,
        user: 'postgres'
      }
    )
    music_database_script = File.read("./test_data/music.pglsql")
    db.turn_off_notices
    db.query(music_database_script)
    db.close
  end

end

RSpec.describe 'Test expand still works with old code, ', type: :feature do
  # Connects to database
  # Supplies migration script
  # Starts the expand process
  # Sets search path to 'laridae_before'
  before do
    @database = DatabaseConnection.new(
      {
        dbname: 'music',
        host: 'localhost',
        port: 5432,
        user: 'postgres'
      }
    )

    @migration_script = {
      operation: 'add_not_null',
      info: {
        schema: 'public',
        table: 'songs',
        column: 'rating'
      },
      functions: {
        up: 'CASE WHEN rating IS NULL THEN 0.0 ELSE rating END',
        down: 'rating'
      }
    }

    @database.turn_off_notices

    operation = AddNotNull.new(@database, JSON.parse(@migration_script.to_json))
    operation.rollback
    operation.expand

    @database.query("SET SEARCH_PATH = 'laridae_before';")
  end

  # Checks that the previously-contained NULL ratings are still in the table
  it 'contains both NULL and non-NULL ratings' do
    null_rating = @database.query('SELECT * FROM songs WHERE rating IS NULL;')
    not_null_rating = @database.query('SELECT * FROM songs WHERE rating IS NOT NULL;')
    expect(null_rating.num_tuples).to be > 0
    expect(not_null_rating.num_tuples).to be > 0
  end

  # Checks that adding NULL to old column is still accepted
  it 'still supports adding NULL ratings' do
    @database.query("INSERT INTO songs (name, artist) VALUES ('null inserted from before', 'new artist');")
    last_row = @database.query("SELECT * FROM songs where name = 'null inserted from before';").first
    expect(last_row['rating']).to be_nil
  end

  # Checks that correctly inserted data or modified data from new code propagates to old code view
  it 'gets data inserted or changed in the new code' do
    @database.query("SET search_path='laridae_after';")
    sql = <<~SQL
      INSERT INTO songs (name, artist, rating) 
        VALUES 
          ('data inserted from after', 'example', 2.3),
          ('data inserted and modified from after', 'example', 3.1);
      UPDATE songs
        SET rating = 4.1 
        WHERE name = 'data inserted and modified from after';
    SQL
    @database.query(sql)
    @database.query("SET search_path='laridae_before';")
    
    inserted_rating = @database.query("SELECT rating FROM songs WHERE name = 'data inserted from after';").first['rating'].to_f
    expect(inserted_rating).to eq(2.3)

    modified_rating = @database.query("SELECT rating FROM songs WHERE name = 'data inserted and modified from after';").first['rating'].to_f
    expect(modified_rating).to eq(4.1)
  end

  after do
    @database.close
  end
end

RSpec.describe 'Test expand will work with new code, ', type: :feature do
  # Connects to database
  # Supplies migration script
  # Starts the expand process
  # Sets search path to 'laridae_after'
  before do
    @database = DatabaseConnection.new(
      {
        dbname: 'music',
        host: 'localhost',
        port: 5432,
        user: 'postgres'
      }
    )

    @migration_script = {
      operation: 'add_not_null',
      info: {
        schema: 'public',
        table: 'songs',
        column: 'rating'
      },
      functions: {
        up: 'CASE WHEN rating IS NULL THEN 0.0 ELSE rating END',
        down: 'rating'
      }
    }

    @database.turn_off_notices

    operation = AddNotNull.new(@database, JSON.parse(@migration_script.to_json))
    operation.rollback
    operation.expand

    @database.query("SET SEARCH_PATH = 'laridae_after';")
  end

  # Checks that all new ratings are not NULL
  it 'does not contain NULL ratings' do
    null_rating_count = @database.query('SELECT * FROM songs WHERE rating IS NULL;').num_tuples
    not_null_rating_count = @database.query('SELECT * FROM songs WHERE rating IS NOT NULL;').num_tuples
    all_rows_count = @database.query('SELECT * from songs;').num_tuples
    expect(null_rating_count).to be 0
    expect(not_null_rating_count).to be > 0
    expect(not_null_rating_count).to be all_rows_count
  end

  # Checks that previously NULL columns are now backfilled
  it 'backfills NULL to 0.0' do
    zero_ratings = @database.query("SELECT rating FROM songs WHERE name = 'Dance All Night' OR name = 'Euphoria';")
                            .map{ |line| line['rating'].to_f }
    zero_ratings.each do |rating|
      expect(rating).to eq(0.0)
    end
  end

  # Checks that NULL inserts from old code is transformed for new code access
  it 'triggers up function for NULL insert from old code' do
    @database.query("SET search_path = 'laridae_before';")
    @database.query("INSERT INTO songs (name, artist) VALUES ('null inserted from after', 'new artist');")
    @database.query("SET search_path = 'laridae_after';")
    up_transformed_rating = @database.query("SELECT rating FROM songs WHERE name = 'null inserted from after';").first['rating'].to_f
    expect(up_transformed_rating).to eq(0.0)
  end

  # Checks that inserting a NULL rating from the new code does not work
  it 'prevents adding NULL to rating' do 
    bad_sql = "INSERT INTO songs (name, artist) VALUES ('no rating song', 'example');"
    expect { @database.query(bad_sql) }.to raise_error(PG::CheckViolation)
  end

  # Checks that correctly inserted data or modified data from old code propagates to old code view
    it 'gets data inserted or changed in the old code' do
      @database.query("SET search_path='laridae_before';")
      sql = <<~SQL
        INSERT INTO songs (name, artist, rating) 
          VALUES 
            ('data inserted from before', 'example', 1.5),
            ('data inserted and modified from before', 'example', 2.0);
        UPDATE songs
          SET rating = 2.5 
          WHERE name = 'data inserted and modified from before';
      SQL
      @database.query(sql)
      @database.query("SET search_path='laridae_after';")
      
      inserted_rating = @database.query("SELECT rating FROM songs WHERE name = 'data inserted from before';").first['rating'].to_f
      expect(inserted_rating).to eq(1.5)
  
      modified_rating = @database.query("SELECT rating FROM songs WHERE name = 'data inserted and modified from before';").first['rating'].to_f
      expect(modified_rating).to eq(2.5)
    end

  after do
    @database.close
  end
end


RSpec.describe 'Test contract will work with new code, ', type: :feature do
  # Connects to database
  # Supplies migration script
  # Complete expand and contract process
  before do
    @database = DatabaseConnection.new(
      {
        dbname: 'music',
        host: 'localhost',
        port: 5432,
        user: 'postgres'
      }
    )

    @migration_script = {
      operation: 'add_not_null',
      info: {
        schema: 'public',
        table: 'songs',
        column: 'rating'
      },
      functions: {
        up: 'CASE WHEN rating IS NULL THEN 0.0 ELSE rating END',
        down: 'rating'
      }
    }

    @database.turn_off_notices

    operation = AddNotNull.new(@database, JSON.parse(@migration_script.to_json))
    operation.rollback
    operation.expand
    operation.contract
  end

  # Checks NOT NULL contraints works completely after contract, NOT NULL constraint 
  it 'prevents adding NULL to rating' do 
    bad_sql = "INSERT INTO songs (name, artist) VALUES ('no rating song', 'example');"
    expect { @database.query(bad_sql) }.to raise_error(PG::CheckViolation)
  end

  # Checks clean up works to delete before and after schemas
  it 'removes before and after schema' do
    laridae_schema_count = @database.query("SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'laridae_before' OR schema_name = 'laridae_after';").num_tuples
    expect(laridae_schema_count).to be 0
  end
end