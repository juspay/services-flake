CREATE TABLE sample_db.ride (`id` Int64, `short_id` String) ENGINE = MergeTree() PRIMARY KEY (id);

INSERT INTO sample_db.ride values (1, 'test_ride');
