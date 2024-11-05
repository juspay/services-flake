CREATE STABLE sample_db.ride (`id` Int64, `short_id` String) ENGINE = MergeTree() PRIMARY KEY (id);

