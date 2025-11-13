--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8 (Debian 15.8-1.pgdg110+1)
-- Dumped by pg_dump version 15.8 (Debian 15.8-1.pgdg110+1)

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
-- Name: telegram; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA telegram;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: users; Type: TABLE; Schema: telegram; Owner: -
--

CREATE TABLE telegram.users (
    id bigint NOT NULL,
    user_id bigint,
    telegram_id bigint NOT NULL,
    telegram_username character varying(255),
    first_name character varying(255),
    last_name character varying(255),
    language_code character varying(8),
    chat_id bigint,
    is_bot boolean DEFAULT false NOT NULL,
    registered_at timestamp(0) without time zone,
    last_active timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    city_id bigint,
    prefs jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: TABLE users; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON TABLE telegram.users IS 'Пользователи Telegram';


--
-- Name: COLUMN users.id; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.id IS 'PK';


--
-- Name: COLUMN users.user_id; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.user_id IS 'ID из таблицы users; null если не привязан';


--
-- Name: COLUMN users.telegram_id; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.telegram_id IS 'Уникальный идентификатор пользователя Telegram (from.id)';


--
-- Name: COLUMN users.telegram_username; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.telegram_username IS '@username (может отсутствовать/меняться)';


--
-- Name: COLUMN users.first_name; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.first_name IS 'Имя в Telegram';


--
-- Name: COLUMN users.last_name; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.last_name IS 'Фамилия в Telegram';


--
-- Name: COLUMN users.language_code; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.language_code IS 'Код языка, например "ru", "en", "en-US"';


--
-- Name: COLUMN users.chat_id; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.chat_id IS 'ID приватного чата с пользователем (chat.id)';


--
-- Name: COLUMN users.is_bot; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.is_bot IS 'Флаг: является ли аккаунт ботом';


--
-- Name: COLUMN users.registered_at; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.registered_at IS 'Когда впервые зафиксирован в системе';


--
-- Name: COLUMN users.last_active; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.last_active IS 'Последняя активность пользователя';


--
-- Name: COLUMN users.city_id; Type: COMMENT; Schema: telegram; Owner: -
--

COMMENT ON COLUMN telegram.users.city_id IS 'ID города из доменного справочника (без FK)';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: telegram; Owner: -
--

CREATE SEQUENCE telegram.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: telegram; Owner: -
--

ALTER SEQUENCE telegram.users_id_seq OWNED BY telegram.users.id;


--
-- Name: users id; Type: DEFAULT; Schema: telegram; Owner: -
--

ALTER TABLE ONLY telegram.users ALTER COLUMN id SET DEFAULT nextval('telegram.users_id_seq'::regclass);


--
-- Name: users telegram_users_telegram_id_uniq; Type: CONSTRAINT; Schema: telegram; Owner: -
--

ALTER TABLE ONLY telegram.users
    ADD CONSTRAINT telegram_users_telegram_id_uniq UNIQUE (telegram_id);


--
-- Name: users telegram_users_telegram_id_unique; Type: CONSTRAINT; Schema: telegram; Owner: -
--

ALTER TABLE ONLY telegram.users
    ADD CONSTRAINT telegram_users_telegram_id_unique UNIQUE (telegram_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: telegram; Owner: -
--

ALTER TABLE ONLY telegram.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: telegram_users_telegram_id_index; Type: INDEX; Schema: telegram; Owner: -
--

CREATE INDEX telegram_users_telegram_id_index ON telegram.users USING btree (telegram_id);


--
-- Name: telegram_users_user_id_index; Type: INDEX; Schema: telegram; Owner: -
--

CREATE INDEX telegram_users_user_id_index ON telegram.users USING btree (user_id);


--
-- Name: tg_users_city_id_idx; Type: INDEX; Schema: telegram; Owner: -
--

CREATE INDEX tg_users_city_id_idx ON telegram.users USING btree (city_id);


--
-- Name: users telegram_users_user_id_foreign; Type: FK CONSTRAINT; Schema: telegram; Owner: -
--

ALTER TABLE ONLY telegram.users
    ADD CONSTRAINT telegram_users_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

