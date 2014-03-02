def setup_database
  DB.create_table! :scores do
    primary_key :id, null: false
    String :player,  null: false, unique: true
    Integer :score,  null: false
  end

  DB[:scores].tap do |scores|
    1_000.times { |i| scores.insert player: "Player #{i}", score: rand(1000) }
  end
end

setup_database

def setup_trigger
  DB.execute <<-SQL
    CREATE OR REPLACE FUNCTION notify_scores() RETURNS trigger AS $$
    BEGIN
      NOTIFY scores;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS scores_trigger ON scores;

    CREATE TRIGGER scores_trigger AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
    ON scores
    EXECUTE PROCEDURE notify_scores();
  SQL
end

setup_trigger
