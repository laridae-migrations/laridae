/* create tables and populate with initial data */
DROP TABLE IF EXISTS public.employees CASCADE;

CREATE TABLE public.employees (
    id serial NOT NULL PRIMARY KEY,
    name text NOT NULL,
    age integer,
    phone text
);

INSERT INTO public.employees VALUES (1, 'Elaina Parry', 43, '888-999-0000');
INSERT INTO public.employees VALUES (2, 'Barton Stone', 25, '1-234-567-8901');
INSERT INTO public.employees VALUES (3, 'Bessie Hopkins', 61, '828-577-2222');
INSERT INTO public.employees VALUES (4, 'Daphne Suarez', 35, '31234');
INSERT INTO public.employees VALUES (5, 'Quintin Curry', 29, '800-232-4574');

/* run this part after expanding to check triggers */

SET SEARCH_PATH = 'laridae_before';
INSERT INTO employees (id, name, age, phone)
VALUES (11, 'inserted into laridae_before', 20, '123-123-1231');
INSERT INTO employees (id, name, age, phone)
VALUES (12, 'inserted into laridae_before with null', 20, NULL);
SET SEARCH_PATH = 'laridae_after';
INSERT INTO employees (id, name, age, phone)
VALUES (13, 'inserted into laridae_after', 40, '123-123-1231');

SET SEARCH_PATH='laridae_before';
UPDATE employees 
  SET phone = '999-999-9999'
  WHERE name = 'inserted into laridae_before';
SET SEARCH_PATH='laridae_after';
UPDATE employees 
  SET phone = '888-888-8888'
  WHERE name = 'inserted into laridae_after';