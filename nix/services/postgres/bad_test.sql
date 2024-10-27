-- Tests if the postgres process gets skipped when there is an error while setting up inital databases
CREATE STABLE users (id INT PRIMARY KEY, user_name VARCHAR(25));

