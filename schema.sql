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
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: attachments; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.attachments (
    id bigint NOT NULL,
    parent_type character varying(255) NOT NULL,
    parent_id bigint NOT NULL,
    type character varying(255) NOT NULL,
    url character varying(255) NOT NULL,
    preview_url character varying(255),
    "order" integer DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.attachments OWNER TO kudab;

--
-- Name: COLUMN attachments.parent_type; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.attachments.parent_type IS 'Тип родительского объекта: context_post, event и др.';


--
-- Name: COLUMN attachments.parent_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.attachments.parent_id IS 'ID родительского объекта';


--
-- Name: COLUMN attachments.type; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.attachments.type IS 'Тип вложения: image, video, file и др.';


--
-- Name: COLUMN attachments.url; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.attachments.url IS 'Ссылка на файл';


--
-- Name: COLUMN attachments.preview_url; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.attachments.preview_url IS 'Ссылка на превью (если есть)';


--
-- Name: COLUMN attachments."order"; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.attachments."order" IS 'Порядок вложения';


--
-- Name: attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.attachments_id_seq OWNER TO kudab;

--
-- Name: attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.attachments_id_seq OWNED BY public.attachments.id;


--
-- Name: cache; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.cache (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    expiration integer NOT NULL
);


ALTER TABLE public.cache OWNER TO kudab;

--
-- Name: cache_locks; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.cache_locks (
    key character varying(255) NOT NULL,
    owner character varying(255) NOT NULL,
    expiration integer NOT NULL
);


ALTER TABLE public.cache_locks OWNER TO kudab;

--
-- Name: communities; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.communities (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    source character varying(255),
    avatar_url character varying(255),
    external_id character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.communities OWNER TO kudab;

--
-- Name: COLUMN communities.name; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.communities.name IS 'Название сообщества';


--
-- Name: COLUMN communities.description; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.communities.description IS 'Описание сообщества';


--
-- Name: COLUMN communities.source; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.communities.source IS 'Источник: vk, tg, site и др.';


--
-- Name: COLUMN communities.avatar_url; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.communities.avatar_url IS 'Ссылка на аватар';


--
-- Name: COLUMN communities.external_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.communities.external_id IS 'ID/slug в исходной соцсети';


--
-- Name: communities_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.communities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.communities_id_seq OWNER TO kudab;

--
-- Name: communities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.communities_id_seq OWNED BY public.communities.id;


--
-- Name: community_interest; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.community_interest (
    community_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.community_interest OWNER TO kudab;

--
-- Name: COLUMN community_interest.community_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.community_interest.community_id IS 'FK на communities.id';


--
-- Name: COLUMN community_interest.interest_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.community_interest.interest_id IS 'FK на interests.id';


--
-- Name: community_social_links; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.community_social_links (
    id bigint NOT NULL,
    community_id bigint NOT NULL,
    social_network_id bigint NOT NULL,
    external_community_id character varying(255),
    url character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.community_social_links OWNER TO kudab;

--
-- Name: COLUMN community_social_links.community_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.community_social_links.community_id IS 'FK на communities.id';


--
-- Name: COLUMN community_social_links.social_network_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.community_social_links.social_network_id IS 'FK на social_networks.id';


--
-- Name: COLUMN community_social_links.external_community_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.community_social_links.external_community_id IS 'ID/slug/username сообщества в соцсети';


--
-- Name: COLUMN community_social_links.url; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.community_social_links.url IS 'Ссылка на профиль сообщества';


--
-- Name: community_social_links_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.community_social_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.community_social_links_id_seq OWNER TO kudab;

--
-- Name: community_social_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.community_social_links_id_seq OWNED BY public.community_social_links.id;


--
-- Name: context_interactions; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.context_interactions (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    user_id bigint NOT NULL,
    type character varying(255) NOT NULL,
    status character varying(255),
    message text,
    reason character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.context_interactions OWNER TO kudab;

--
-- Name: COLUMN context_interactions.post_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_interactions.post_id IS 'FK на context_posts.id';


--
-- Name: COLUMN context_interactions.user_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_interactions.user_id IS 'FK на users.id';


--
-- Name: COLUMN context_interactions.type; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_interactions.type IS 'Тип действия: request, response, flag, comment и др.';


--
-- Name: COLUMN context_interactions.status; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_interactions.status IS 'Статус действия: active, reviewed, flagged и др.';


--
-- Name: COLUMN context_interactions.message; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_interactions.message IS 'Сообщение, комментарий, ответ';


--
-- Name: COLUMN context_interactions.reason; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_interactions.reason IS 'Причина/категория, если применимо';


--
-- Name: context_interactions_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.context_interactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.context_interactions_id_seq OWNER TO kudab;

--
-- Name: context_interactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.context_interactions_id_seq OWNED BY public.context_interactions.id;


--
-- Name: context_posts; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.context_posts (
    id bigint NOT NULL,
    external_id character varying(255),
    source character varying(255),
    author_id bigint,
    author_type character varying(255),
    community_id bigint,
    title character varying(255),
    text text,
    published_at timestamp(0) without time zone,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.context_posts OWNER TO kudab;

--
-- Name: COLUMN context_posts.external_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_posts.external_id IS 'ID исходного поста VK/TG/сайт';


--
-- Name: COLUMN context_posts.source; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_posts.source IS 'vk, tg, site и др.';


--
-- Name: COLUMN context_posts.author_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_posts.author_id IS 'ID автора (user/community/external)';


--
-- Name: COLUMN context_posts.author_type; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_posts.author_type IS 'user, community, external';


--
-- Name: COLUMN context_posts.community_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_posts.community_id IS 'FK на communities.id';


--
-- Name: COLUMN context_posts.status; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.context_posts.status IS 'active, flagged, hidden и др.';


--
-- Name: context_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.context_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.context_posts_id_seq OWNER TO kudab;

--
-- Name: context_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.context_posts_id_seq OWNED BY public.context_posts.id;


--
-- Name: event_attendees; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.event_attendees (
    event_id bigint NOT NULL,
    user_id bigint NOT NULL,
    status character varying(255) DEFAULT 'going'::character varying NOT NULL,
    joined_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.event_attendees OWNER TO kudab;

--
-- Name: COLUMN event_attendees.event_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.event_attendees.event_id IS 'FK на events.id';


--
-- Name: COLUMN event_attendees.user_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.event_attendees.user_id IS 'FK на users.id';


--
-- Name: COLUMN event_attendees.status; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.event_attendees.status IS 'Статус участия: going, interested, rejected и др.';


--
-- Name: COLUMN event_attendees.joined_at; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.event_attendees.joined_at IS 'Время присоединения';


--
-- Name: event_interest; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.event_interest (
    event_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.event_interest OWNER TO kudab;

--
-- Name: COLUMN event_interest.event_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.event_interest.event_id IS 'FK на events.id';


--
-- Name: COLUMN event_interest.interest_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.event_interest.interest_id IS 'FK на interests.id';


--
-- Name: events; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    original_post_id bigint,
    community_id bigint NOT NULL,
    title character varying(255) NOT NULL,
    start_time timestamp(0) without time zone NOT NULL,
    end_time timestamp(0) without time zone,
    city character varying(255),
    address character varying(255),
    description text,
    status character varying(255) DEFAULT 'active'::character varying NOT NULL,
    external_url character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    deleted_at timestamp(0) without time zone,
    location public.geometry(Point,4326) NOT NULL,
    latitude numeric(9,6) GENERATED ALWAYS AS (public.st_y((location)::public.geometry)) STORED,
    longitude numeric(9,6) GENERATED ALWAYS AS (public.st_x((location)::public.geometry)) STORED
);


ALTER TABLE public.events OWNER TO kudab;

--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.events_id_seq OWNER TO kudab;

--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: failed_jobs; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.failed_jobs (
    id bigint NOT NULL,
    uuid character varying(255) NOT NULL,
    connection text NOT NULL,
    queue text NOT NULL,
    payload text NOT NULL,
    exception text NOT NULL,
    failed_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.failed_jobs OWNER TO kudab;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.failed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.failed_jobs_id_seq OWNER TO kudab;

--
-- Name: failed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.failed_jobs_id_seq OWNED BY public.failed_jobs.id;


--
-- Name: interest_links; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.interest_links (
    parent_type character varying(255) NOT NULL,
    parent_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.interest_links OWNER TO kudab;

--
-- Name: COLUMN interest_links.parent_type; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_links.parent_type IS 'Тип объекта: context_post, event и др.';


--
-- Name: COLUMN interest_links.parent_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_links.parent_id IS 'ID объекта';


--
-- Name: COLUMN interest_links.interest_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_links.interest_id IS 'FK на interests.id';


--
-- Name: interest_relations; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.interest_relations (
    id bigint NOT NULL,
    parent_interest_id bigint NOT NULL,
    child_interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.interest_relations OWNER TO kudab;

--
-- Name: COLUMN interest_relations.parent_interest_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_relations.parent_interest_id IS 'FK на interests.id (родитель)';


--
-- Name: COLUMN interest_relations.child_interest_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_relations.child_interest_id IS 'FK на interests.id (дочерний)';


--
-- Name: interest_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.interest_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.interest_relations_id_seq OWNER TO kudab;

--
-- Name: interest_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.interest_relations_id_seq OWNED BY public.interest_relations.id;


--
-- Name: interest_user; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.interest_user (
    user_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.interest_user OWNER TO kudab;

--
-- Name: COLUMN interest_user.user_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_user.user_id IS 'FK на users.id';


--
-- Name: COLUMN interest_user.interest_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interest_user.interest_id IS 'FK на interests.id';


--
-- Name: interests; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.interests (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    parent_id bigint,
    is_paid boolean DEFAULT false NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.interests OWNER TO kudab;

--
-- Name: COLUMN interests.name; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interests.name IS 'Название интереса';


--
-- Name: COLUMN interests.parent_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interests.parent_id IS 'FK на interests.id, для дерева интересов';


--
-- Name: COLUMN interests.is_paid; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.interests.is_paid IS 'Платный интерес?';


--
-- Name: interests_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.interests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.interests_id_seq OWNER TO kudab;

--
-- Name: interests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.interests_id_seq OWNED BY public.interests.id;


--
-- Name: job_batches; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.job_batches (
    id character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    total_jobs integer NOT NULL,
    pending_jobs integer NOT NULL,
    failed_jobs integer NOT NULL,
    failed_job_ids text NOT NULL,
    options text,
    cancelled_at integer,
    created_at integer NOT NULL,
    finished_at integer
);


ALTER TABLE public.job_batches OWNER TO kudab;

--
-- Name: jobs; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.jobs (
    id bigint NOT NULL,
    queue character varying(255) NOT NULL,
    payload text NOT NULL,
    attempts smallint NOT NULL,
    reserved_at integer,
    available_at integer NOT NULL,
    created_at integer NOT NULL
);


ALTER TABLE public.jobs OWNER TO kudab;

--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.jobs_id_seq OWNER TO kudab;

--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    migration character varying(255) NOT NULL,
    batch integer NOT NULL
);


ALTER TABLE public.migrations OWNER TO kudab;

--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.migrations_id_seq OWNER TO kudab;

--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.password_reset_tokens (
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    created_at timestamp(0) without time zone
);


ALTER TABLE public.password_reset_tokens OWNER TO kudab;

--
-- Name: personal_access_tokens; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.personal_access_tokens (
    id bigint NOT NULL,
    tokenable_type character varying(255) NOT NULL,
    tokenable_id bigint NOT NULL,
    name text NOT NULL,
    token character varying(64) NOT NULL,
    abilities text,
    last_used_at timestamp(0) without time zone,
    expires_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.personal_access_tokens OWNER TO kudab;

--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.personal_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.personal_access_tokens_id_seq OWNER TO kudab;

--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.personal_access_tokens_id_seq OWNED BY public.personal_access_tokens.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.sessions (
    id character varying(255) NOT NULL,
    user_id bigint,
    ip_address character varying(45),
    user_agent text,
    payload text NOT NULL,
    last_activity integer NOT NULL
);


ALTER TABLE public.sessions OWNER TO kudab;

--
-- Name: social_networks; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.social_networks (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    slug character varying(255) NOT NULL,
    icon character varying(255),
    url_mask character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.social_networks OWNER TO kudab;

--
-- Name: COLUMN social_networks.name; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.social_networks.name IS 'Название соцсети (VK, Telegram, Instagram, ...)';


--
-- Name: COLUMN social_networks.slug; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.social_networks.slug IS 'Слаг: vk, telegram, instagram и др.';


--
-- Name: COLUMN social_networks.icon; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.social_networks.icon IS 'Иконка/emoji или URL';


--
-- Name: COLUMN social_networks.url_mask; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.social_networks.url_mask IS 'Шаблон для генерации ссылок';


--
-- Name: social_networks_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.social_networks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.social_networks_id_seq OWNER TO kudab;

--
-- Name: social_networks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.social_networks_id_seq OWNED BY public.social_networks.id;


--
-- Name: telegram_users; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.telegram_users (
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
    updated_at timestamp(0) without time zone
);


ALTER TABLE public.telegram_users OWNER TO kudab;

--
-- Name: COLUMN telegram_users.user_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.user_id IS 'FK на users.id, опционально';


--
-- Name: COLUMN telegram_users.telegram_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.telegram_id IS 'Telegram user ID (уникальный)';


--
-- Name: COLUMN telegram_users.telegram_username; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.telegram_username IS 'username в Telegram';


--
-- Name: COLUMN telegram_users.first_name; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.first_name IS 'Имя пользователя в Telegram';


--
-- Name: COLUMN telegram_users.last_name; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.last_name IS 'Фамилия пользователя в Telegram';


--
-- Name: COLUMN telegram_users.language_code; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.language_code IS 'Язык пользователя';


--
-- Name: COLUMN telegram_users.chat_id; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.chat_id IS 'Активный chat_id Telegram';


--
-- Name: COLUMN telegram_users.is_bot; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.is_bot IS 'Это бот-пользователь';


--
-- Name: COLUMN telegram_users.registered_at; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.registered_at IS 'Первое посещение';


--
-- Name: COLUMN telegram_users.last_active; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.telegram_users.last_active IS 'Последняя активность';


--
-- Name: telegram_users_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.telegram_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.telegram_users_id_seq OWNER TO kudab;

--
-- Name: telegram_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.telegram_users_id_seq OWNED BY public.telegram_users.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: kudab
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    email_verified_at timestamp(0) without time zone,
    password character varying(255) NOT NULL,
    remember_token character varying(100),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    avatar_url character varying(255),
    bio text,
    deleted_at timestamp(0) without time zone
);


ALTER TABLE public.users OWNER TO kudab;

--
-- Name: COLUMN users.avatar_url; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.users.avatar_url IS 'Ссылка на аватар пользователя';


--
-- Name: COLUMN users.bio; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.users.bio IS 'Коротко о себе';


--
-- Name: COLUMN users.deleted_at; Type: COMMENT; Schema: public; Owner: kudab
--

COMMENT ON COLUMN public.users.deleted_at IS 'Мягкое удаление';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: kudab
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO kudab;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kudab
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: attachments id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.attachments ALTER COLUMN id SET DEFAULT nextval('public.attachments_id_seq'::regclass);


--
-- Name: communities id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.communities ALTER COLUMN id SET DEFAULT nextval('public.communities_id_seq'::regclass);


--
-- Name: community_social_links id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_social_links ALTER COLUMN id SET DEFAULT nextval('public.community_social_links_id_seq'::regclass);


--
-- Name: context_interactions id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_interactions ALTER COLUMN id SET DEFAULT nextval('public.context_interactions_id_seq'::regclass);


--
-- Name: context_posts id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_posts ALTER COLUMN id SET DEFAULT nextval('public.context_posts_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: failed_jobs id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.failed_jobs ALTER COLUMN id SET DEFAULT nextval('public.failed_jobs_id_seq'::regclass);


--
-- Name: interest_relations id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_relations ALTER COLUMN id SET DEFAULT nextval('public.interest_relations_id_seq'::regclass);


--
-- Name: interests id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interests ALTER COLUMN id SET DEFAULT nextval('public.interests_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: personal_access_tokens id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.personal_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.personal_access_tokens_id_seq'::regclass);


--
-- Name: social_networks id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.social_networks ALTER COLUMN id SET DEFAULT nextval('public.social_networks_id_seq'::regclass);


--
-- Name: telegram_users id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.telegram_users ALTER COLUMN id SET DEFAULT nextval('public.telegram_users_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: cache_locks cache_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.cache_locks
    ADD CONSTRAINT cache_locks_pkey PRIMARY KEY (key);


--
-- Name: cache cache_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (key);


--
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (id);


--
-- Name: community_interest community_interest_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_interest
    ADD CONSTRAINT community_interest_pkey PRIMARY KEY (community_id, interest_id);


--
-- Name: community_social_links community_social_links_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_pkey PRIMARY KEY (id);


--
-- Name: context_interactions context_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_interactions
    ADD CONSTRAINT context_interactions_pkey PRIMARY KEY (id);


--
-- Name: context_posts context_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_posts
    ADD CONSTRAINT context_posts_pkey PRIMARY KEY (id);


--
-- Name: event_attendees event_attendees_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.event_attendees
    ADD CONSTRAINT event_attendees_pkey PRIMARY KEY (event_id, user_id);


--
-- Name: event_interest event_interest_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.event_interest
    ADD CONSTRAINT event_interest_pkey PRIMARY KEY (event_id, interest_id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_uuid_unique UNIQUE (uuid);


--
-- Name: interest_links interest_links_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_links
    ADD CONSTRAINT interest_links_pkey PRIMARY KEY (parent_type, parent_id, interest_id);


--
-- Name: interest_relations interest_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT interest_relations_pkey PRIMARY KEY (id);


--
-- Name: interest_user interest_user_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_user
    ADD CONSTRAINT interest_user_pkey PRIMARY KEY (user_id, interest_id);


--
-- Name: interests interests_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interests
    ADD CONSTRAINT interests_pkey PRIMARY KEY (id);


--
-- Name: job_batches job_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.job_batches
    ADD CONSTRAINT job_batches_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email);


--
-- Name: personal_access_tokens personal_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_token_unique; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_token_unique UNIQUE (token);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: social_networks social_networks_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.social_networks
    ADD CONSTRAINT social_networks_pkey PRIMARY KEY (id);


--
-- Name: social_networks social_networks_slug_unique; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.social_networks
    ADD CONSTRAINT social_networks_slug_unique UNIQUE (slug);


--
-- Name: telegram_users telegram_users_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.telegram_users
    ADD CONSTRAINT telegram_users_pkey PRIMARY KEY (id);


--
-- Name: telegram_users telegram_users_telegram_id_unique; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.telegram_users
    ADD CONSTRAINT telegram_users_telegram_id_unique UNIQUE (telegram_id);


--
-- Name: interest_relations unique_interest_relation; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT unique_interest_relation UNIQUE (parent_interest_id, child_interest_id);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: attachments_parent_type_parent_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX attachments_parent_type_parent_id_index ON public.attachments USING btree (parent_type, parent_id);


--
-- Name: attachments_type_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX attachments_type_index ON public.attachments USING btree (type);


--
-- Name: communities_external_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX communities_external_id_index ON public.communities USING btree (external_id);


--
-- Name: communities_source_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX communities_source_index ON public.communities USING btree (source);


--
-- Name: community_social_links_community_id_social_network_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX community_social_links_community_id_social_network_id_index ON public.community_social_links USING btree (community_id, social_network_id);


--
-- Name: community_social_links_external_community_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX community_social_links_external_community_id_index ON public.community_social_links USING btree (external_community_id);


--
-- Name: context_interactions_post_id_user_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_interactions_post_id_user_id_index ON public.context_interactions USING btree (post_id, user_id);


--
-- Name: context_interactions_status_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_interactions_status_index ON public.context_interactions USING btree (status);


--
-- Name: context_interactions_type_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_interactions_type_index ON public.context_interactions USING btree (type);


--
-- Name: context_posts_external_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_posts_external_id_index ON public.context_posts USING btree (external_id);


--
-- Name: context_posts_published_at_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_posts_published_at_index ON public.context_posts USING btree (published_at);


--
-- Name: context_posts_source_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_posts_source_index ON public.context_posts USING btree (source);


--
-- Name: context_posts_status_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX context_posts_status_index ON public.context_posts USING btree (status);


--
-- Name: event_attendees_status_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX event_attendees_status_index ON public.event_attendees USING btree (status);


--
-- Name: events_city_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX events_city_index ON public.events USING btree (city);


--
-- Name: events_location_gix; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX events_location_gix ON public.events USING gist (location);


--
-- Name: events_start_time_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX events_start_time_index ON public.events USING btree (start_time);


--
-- Name: events_status_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX events_status_index ON public.events USING btree (status);


--
-- Name: interest_links_parent_type_parent_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX interest_links_parent_type_parent_id_index ON public.interest_links USING btree (parent_type, parent_id);


--
-- Name: interest_relations_parent_interest_id_child_interest_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX interest_relations_parent_interest_id_child_interest_id_index ON public.interest_relations USING btree (parent_interest_id, child_interest_id);


--
-- Name: interests_name_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX interests_name_index ON public.interests USING btree (name);


--
-- Name: interests_parent_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX interests_parent_id_index ON public.interests USING btree (parent_id);


--
-- Name: jobs_queue_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX jobs_queue_index ON public.jobs USING btree (queue);


--
-- Name: personal_access_tokens_tokenable_type_tokenable_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX personal_access_tokens_tokenable_type_tokenable_id_index ON public.personal_access_tokens USING btree (tokenable_type, tokenable_id);


--
-- Name: sessions_last_activity_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX sessions_last_activity_index ON public.sessions USING btree (last_activity);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX sessions_user_id_index ON public.sessions USING btree (user_id);


--
-- Name: social_networks_name_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX social_networks_name_index ON public.social_networks USING btree (name);


--
-- Name: telegram_users_last_active_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX telegram_users_last_active_index ON public.telegram_users USING btree (last_active);


--
-- Name: telegram_users_telegram_username_index; Type: INDEX; Schema: public; Owner: kudab
--

CREATE INDEX telegram_users_telegram_username_index ON public.telegram_users USING btree (telegram_username);


--
-- Name: community_interest community_interest_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_interest
    ADD CONSTRAINT community_interest_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_interest community_interest_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_interest
    ADD CONSTRAINT community_interest_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: community_social_links community_social_links_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_social_links community_social_links_social_network_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_social_network_id_foreign FOREIGN KEY (social_network_id) REFERENCES public.social_networks(id) ON DELETE CASCADE;


--
-- Name: context_interactions context_interactions_post_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_interactions
    ADD CONSTRAINT context_interactions_post_id_foreign FOREIGN KEY (post_id) REFERENCES public.context_posts(id) ON DELETE CASCADE;


--
-- Name: context_interactions context_interactions_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_interactions
    ADD CONSTRAINT context_interactions_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: context_posts context_posts_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.context_posts
    ADD CONSTRAINT context_posts_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE SET NULL;


--
-- Name: event_attendees event_attendees_event_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.event_attendees
    ADD CONSTRAINT event_attendees_event_id_foreign FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_attendees event_attendees_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.event_attendees
    ADD CONSTRAINT event_attendees_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: event_interest event_interest_event_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.event_interest
    ADD CONSTRAINT event_interest_event_id_foreign FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_interest event_interest_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.event_interest
    ADD CONSTRAINT event_interest_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: events events_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: events events_original_post_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_original_post_id_foreign FOREIGN KEY (original_post_id) REFERENCES public.context_posts(id) ON DELETE SET NULL;


--
-- Name: interest_links interest_links_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_links
    ADD CONSTRAINT interest_links_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_relations interest_relations_child_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT interest_relations_child_interest_id_foreign FOREIGN KEY (child_interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_relations interest_relations_parent_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT interest_relations_parent_interest_id_foreign FOREIGN KEY (parent_interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_user interest_user_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_user
    ADD CONSTRAINT interest_user_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_user interest_user_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interest_user
    ADD CONSTRAINT interest_user_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: interests interests_parent_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.interests
    ADD CONSTRAINT interests_parent_id_foreign FOREIGN KEY (parent_id) REFERENCES public.interests(id) ON DELETE SET NULL;


--
-- Name: telegram_users telegram_users_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: kudab
--

ALTER TABLE ONLY public.telegram_users
    ADD CONSTRAINT telegram_users_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

