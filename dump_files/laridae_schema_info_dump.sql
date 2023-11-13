--
-- PostgreSQL database dump
--

-- Dumped from database version 14.9 (Homebrew)
-- Dumped by pg_dump version 14.9 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: laridae; Type: SCHEMA; Schema: -; Owner: stephanie
--

CREATE SCHEMA laridae;


ALTER SCHEMA laridae OWNER TO stephanie;

--
-- Name: public_01_original_employees_table; Type: SCHEMA; Schema: -; Owner: stephanie
--

CREATE SCHEMA public_01_original_employees_table;


ALTER SCHEMA public_01_original_employees_table OWNER TO stephanie;

--
-- Name: public_02_employees_phone_not_null; Type: SCHEMA; Schema: -; Owner: stephanie
--

CREATE SCHEMA public_02_employees_phone_not_null;


ALTER SCHEMA public_02_employees_phone_not_null OWNER TO stephanie;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: open_migration; Type: TABLE; Schema: laridae; Owner: stephanie
--

CREATE TABLE laridae.open_migration (
    script jsonb
);


ALTER TABLE laridae.open_migration OWNER TO stephanie;

--
-- Name: employees; Type: TABLE; Schema: public; Owner: stephanie
--

CREATE TABLE public.employees (
    id integer NOT NULL,
    name text NOT NULL,
    age integer,
    phone text,
    age_insert_ex integer,
    computer_id integer,
    laridae_new_computer_id integer,
    description text,
    price integer DEFAULT 12,
    laridae_new_age integer,
    CONSTRAINT age_check CHECK ((age >= 18)),
    CONSTRAINT description_length CHECK ((length(description) <= 64))
);


ALTER TABLE public.employees OWNER TO stephanie;

--
-- Name: employees_id_seq; Type: SEQUENCE; Schema: public; Owner: stephanie
--

CREATE SEQUENCE public.employees_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.employees_id_seq OWNER TO stephanie;

--
-- Name: employees_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stephanie
--

ALTER SEQUENCE public.employees_id_seq OWNED BY public.employees.id;


--
-- Name: phones; Type: TABLE; Schema: public; Owner: stephanie
--

CREATE TABLE public.phones (
    id integer NOT NULL,
    employee_id integer,
    number text,
    CONSTRAINT phone_check CHECK ((number ~ '^\d{10}$'::text))
);


ALTER TABLE public.phones OWNER TO stephanie;

--
-- Name: phones_ex; Type: TABLE; Schema: public; Owner: stephanie
--

CREATE TABLE public.phones_ex (
    id integer,
    employee_id integer,
    number text,
    laridae_new_employee_id integer
);


ALTER TABLE public.phones_ex OWNER TO stephanie;

--
-- Name: phones_id_seq; Type: SEQUENCE; Schema: public; Owner: stephanie
--

CREATE SEQUENCE public.phones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.phones_id_seq OWNER TO stephanie;

--
-- Name: phones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: stephanie
--

ALTER SEQUENCE public.phones_id_seq OWNED BY public.phones.id;


--
-- Name: employees; Type: VIEW; Schema: public_01_original_employees_table; Owner: stephanie
--

CREATE VIEW public_01_original_employees_table.employees AS
 SELECT employees.id,
    employees.name,
    employees.age,
    employees.phone
   FROM public.employees;


ALTER TABLE public_01_original_employees_table.employees OWNER TO stephanie;

--
-- Name: latest_schema; Type: TABLE; Schema: public_01_original_employees_table; Owner: stephanie
--

CREATE TABLE public_01_original_employees_table.latest_schema (
    "?column?" text COLLATE pg_catalog."C"
);


ALTER TABLE public_01_original_employees_table.latest_schema OWNER TO stephanie;

--
-- Name: employees id; Type: DEFAULT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.employees ALTER COLUMN id SET DEFAULT nextval('public.employees_id_seq'::regclass);


--
-- Name: phones id; Type: DEFAULT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.phones ALTER COLUMN id SET DEFAULT nextval('public.phones_id_seq'::regclass);


--
-- Name: employees employees_laridae_new_computer_id_key; Type: CONSTRAINT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_laridae_new_computer_id_key UNIQUE (laridae_new_computer_id);


--
-- Name: employees employees_pkey; Type: CONSTRAINT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.employees
    ADD CONSTRAINT employees_pkey PRIMARY KEY (id);


--
-- Name: phones phones_pkey; Type: CONSTRAINT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.phones
    ADD CONSTRAINT phones_pkey PRIMARY KEY (id);


--
-- Name: phones_ex fk_employee_id; Type: FK CONSTRAINT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.phones_ex
    ADD CONSTRAINT fk_employee_id FOREIGN KEY (laridae_new_employee_id) REFERENCES public.employees(id);


--
-- Name: phones phones_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: stephanie
--

ALTER TABLE ONLY public.phones
    ADD CONSTRAINT phones_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.employees(id);


--
-- PostgreSQL database dump complete
--

