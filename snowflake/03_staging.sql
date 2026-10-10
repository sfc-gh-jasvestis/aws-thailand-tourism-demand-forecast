-- Validate the producer contract before building downstream objects.
USE DATABASE IDENTIFIER($DEMO_DB);
USE SCHEMA RAW;
USE WAREHOUSE IDENTIFIER($DEMO_WH);

EXECUTE IMMEDIATE $$
DECLARE
  violations INTEGER;
  invalid_source EXCEPTION (-20001, 'Synthetic source failed grain or measure validation');
BEGIN
  SELECT COUNT(*) INTO :violations FROM (
    SELECT ENTITY_ID, EVENT_DATE
    FROM RAW.PROPERTY_DAILY
    GROUP BY ENTITY_ID, EVENT_DATE HAVING COUNT(*) <> 1
    UNION ALL
    SELECT observation.ENTITY_ID, observation.EVENT_DATE
    FROM RAW.PROPERTY_DAILY observation
    LEFT JOIN RAW.HOTEL_PROPERTIES prop ON prop.ID = observation.ENTITY_ID
    WHERE prop.ID IS NULL OR observation.ROOM_NIGHTS < 0
       OR observation.ROOM_REVENUE_THB < 0
       OR observation.SELLOUT_COUNT < 0 OR observation.SELLOUT_COUNT > observation.PACE_FLAG_COUNT
       OR observation.PACE_FLAG_COUNT > observation.ROOM_NIGHTS
       OR observation.ALLOTMENT_RECALL > observation.SELLOUT_COUNT
       OR observation.PICKUP_REVIEW_DONE > observation.PICKUP_REVIEW_DUE
  );
  IF (violations > 0) THEN
    RAISE invalid_source;
  END IF;
END;
$$;
