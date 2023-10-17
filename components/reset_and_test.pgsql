DROP TABLE IF EXISTS public.employees CASCADE;
DROP TABLE IF EXISTS public.phones CASCADE;

CREATE TABLE public.employees (
    id serial NOT NULL PRIMARY KEY,
    name text NOT NULL,
    age integer,
    phone text
);

CREATE TABLE public.phones (
    id serial NOT NULL PRIMARY KEY,
    employee_id integer REFERENCES public.employees (id),
    number text,
    CONSTRAINT phone_check CHECK ((number ~ '^\d{10}$'::text))
);

INSERT INTO public.employees VALUES (1, 'Elaina Parry', 43, NULL);
INSERT INTO public.employees VALUES (2, 'Barton Stone', 25, NULL);
INSERT INTO public.employees VALUES (3, 'Bessie Hopkins', 61, NULL);
INSERT INTO public.employees VALUES (4, 'Daphne Suarez', 35, NULL);
INSERT INTO public.employees VALUES (5, 'Quintin Curry', 29, NULL);

INSERT INTO public.phones VALUES (1, 1, '3457347645');
INSERT INTO public.phones VALUES (2, 2, '4934161408');
INSERT INTO public.phones VALUES (3, 3, '5886550296');
INSERT INTO public.phones VALUES (4, 4, '7433751878');
INSERT INTO public.phones VALUES (5, 5, '5089774948');

SET SEARCH_PATH = 'before';
INSERT INTO employees (id, name, age, phone)
VALUES (11, 'inserted into before', 20, '1231231231');
INSERT INTO employees (id, name, age, phone)
VALUES (12, 'inserted into before with null', 20, NULL);
SET SEARCH_PATH = 'after';
INSERT INTO employees (id, name, age, phone)
VALUES (13, 'inserted into after', 40, '1231231231');

SET SEARCH_PATH='before';
UPDATE employees 
  SET phone = '9999999999'
  WHERE name = 'inserted into before';
SET SEARCH_PATH='after';
UPDATE employees 
  SET phone = '8888888888'
  WHERE name = 'inserted into after';