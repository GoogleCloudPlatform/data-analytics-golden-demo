-- Run this on AlloyDB

CREATE TABLE room (
    room_id INT PRIMARY KEY,
    room_type VARCHAR(50),
    bed_type VARCHAR(50),
    square_feet INT
);

CREATE TABLE room_amenity (
    room_id INT,
    room_feature VARCHAR(255),
    PRIMARY KEY (room_id, room_feature),
    FOREIGN KEY (room_id) REFERENCES room(room_id)
);

CREATE TABLE room_rate (
    room_id INT,
    date DATE,
    room_rate DECIMAL(10, 2),
    PRIMARY KEY (room_id, date),
    FOREIGN KEY (room_id) REFERENCES room(room_id)
);


-- INSERT statements for the 'room' table

-- Generate 100 room records
DO $$
DECLARE
  i INT := 1;
  room_type_options TEXT[] := ARRAY['Standard', 'Deluxe', 'Suite', 'Family', 'Studio'];
  bed_type_options TEXT[] := ARRAY['King', 'Queen', '2 Doubles', 'Twin'];
  has_balcony BOOLEAN;
  square_feet INT;
BEGIN
  WHILE i <= 100 LOOP
    -- Randomly decide if room has balcony
    has_balcony := (random() < 0.30); -- 30% of rooms have balconies

    -- Set square footage based on balcony status and add variance
    IF has_balcony THEN
      square_feet := round(458 + (random() * 100) - 50); -- Average 458, variance +/- 50
    ELSE
      square_feet := round(412 + (random() * 100) - 50); -- Average 412, variance +/- 50
    END IF;

    -- Ensure square footage is within reasonable bounds
    square_feet := LEAST(GREATEST(square_feet, 200), 800);

    INSERT INTO room (room_id, room_type, bed_type, square_feet)
    VALUES (i,
            room_type_options[ceil(random() * array_length(room_type_options, 1))],
            bed_type_options[ceil(random() * array_length(bed_type_options, 1))],
            square_feet);

    i := i + 1;
  END LOOP;
END $$;

-- INSERT statements for the 'room_amenity' table
-- Using the de-duplicated room_feature list
DO $$
DECLARE
  i INT := 1;
  num_amenities INT;
  amenities TEXT[] := ARRAY[
    'Balcony', 'Mini-fridge', 'Work Desk', 'Premium Bedding', 'Ocean View',
    'Luxury Bathrobes', 'Shoeshine Service', 'Whirlpool Bath', 'Microwave',
    'Turndown Service', 'Hair Dryer', 'Blackout Curtains', 'Gourmet Coffee Machine',
    'Turkish Cotton Towels', 'Fireplace', 'Iron & Ironing Board', 'Connecting Rooms',
    'Welcome Gift'
  ];
  amenity_index INT;
  amenity TEXT;
  room_has_balcony BOOLEAN;
BEGIN
  WHILE i <= 100 LOOP
    -- Get number of amenities for the room (between 2 and 5)
    num_amenities := floor(2 + random() * 4);  -- Generates random int between 2 and 5

        -- Check if the room has a balcony
    SELECT EXISTS (SELECT 1 FROM room WHERE room_id = i AND square_feet > 430) INTO room_has_balcony;

    -- Add amenities
    FOR j IN 1..num_amenities LOOP
      -- Pick a random amenity
      WHILE TRUE LOOP
        amenity_index := ceil(random() * array_length(amenities, 1));
        amenity := amenities[amenity_index];
            -- Prevent adding 'Balcony' to rooms that don't have balconies, and avoid duplicates
            IF (amenity <> 'Balcony' OR room_has_balcony) AND NOT EXISTS (
                SELECT 1
                FROM room_amenity
                WHERE room_id = i AND room_feature = amenity
            ) THEN
              EXIT; -- Exit the loop if valid and not a duplicate
            END IF;
        END LOOP;

      -- Insert the amenity for the room
      INSERT INTO room_amenity (room_id, room_feature) VALUES (i, amenity);
    END LOOP;

    i := i + 1;
  END LOOP;
END $$;


-- INSERT statements for the 'room_rate' table (REVISED - Casting to numeric for round())
DO $$
DECLARE
  i INT;
  room_price DECIMAL(10, 2);
  start_date DATE := '2025-03-01';
  end_date DATE := '2025-04-14';
  the_current_date DATE;  -- Using the renamed variable from the last attempt
  has_balcony BOOLEAN;
  day_offset INT;
BEGIN
  FOR i IN 1..100 LOOP
    FOR day_offset IN 0..(end_date - start_date) LOOP
        the_current_date := start_date + day_offset;

      -- Check if the room has a balcony
      SELECT EXISTS (SELECT 1 FROM room WHERE room_id = i AND square_feet > 430) INTO has_balcony;

      -- Determine base price based on balcony (WITH CASTING)
      IF has_balcony THEN
        room_price := round((307 - 20 + (random() * 40) - 20)::numeric, 2);
      ELSE
        room_price := round((257 - 20 + (random() * 40) - 20)::numeric, 2);
      END IF;

      -- Ensure price is within a reasonable range (already correct)
      room_price := LEAST(GREATEST(room_price, 80), 500);

      INSERT INTO room_rate (room_id, date, room_rate)
      VALUES (i, the_current_date, room_price);

    END LOOP;
  END LOOP;
END $$;


------------------------------------------------------------------------------------------------------------------------------
-- Load data
------------------------------------------------------------------------------------------------------------------------------
select * from room;

select * from room_amenity;

select * from room_rate;


-- setup AlloyDB for vector embeddings
/*
-- One time thing
SELECT extversion FROM pg_extension WHERE extname = 'google_ml_integration';
CREATE EXTENSION IF NOT EXISTS google_ml_integration VERSION '1.2';
GRANT EXECUTE ON FUNCTION embedding TO postgres;
CREATE EXTENSION IF NOT EXISTS vector;
*/

-- Create embedding on our hotel data
ALTER TABLE room_amenity ADD COLUMN vector_embedding real[768];
UPDATE room_amenity SET vector_embedding = embedding('text-embedding-005', room_feature);


-- Vector Search (order by distance)
-- The competition uses "Thick Terry Bathrobes", find what we use 
SELECT * , 
       vector_embedding::vector <-> embedding('text-embedding-005', 'Thick Terry Bathrobes')::vector AS distance
  FROM room_amenity
 ORDER BY distance
 LIMIT 100;

-- The competition uses "Terrace", what do we use?
SELECT * , 
       vector_embedding::vector <-> embedding('text-embedding-005', 'Terrace')::vector AS distance
  FROM room_amenity
 ORDER BY distance
 LIMIT 10;


-- Compute our average square feet and price for rooms with and without a Balcony
SELECT 'Balcony' AS amenity,
       AVG(room.square_feet) AS average_sq_ft,
       AVG(room_rate.room_rate) AS average_price
  FROM room
       INNER JOIN room_amenity
               ON room.room_id= room_amenity.room_id
              AND room_amenity.room_feature = 'Balcony' 
       INNER JOIN room_rate
               ON room_rate.room_id = room.room_id
UNION ALL
SELECT 'No Balcony' AS amenity,
       AVG(room.square_feet) AS average_sq_ft,
       AVG(room_rate.room_rate) AS average_price
  FROM room
       INNER JOIN room_rate
               ON room_rate.room_id = room.room_id
              AND room.room_id NOT IN (SELECT room_id FROM room_amenity WHERE room_feature = 'Balcony');

-- BigQuery Competitor Data
-- Balcony	     458.04878048780489	    307.75609756097560975609756097560975609756	
-- No Balcony    412.32704402515708	   257.00415094339622641509433962264150943396

-- AlloyDB
-- Balcony          461.1428571428571429  286.2921904761904762
-- No Balcony       419.8494623655913978  257.4768936678614098
