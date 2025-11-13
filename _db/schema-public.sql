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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


--
-- Name: attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachments (
    id bigint NOT NULL,
    parent_type character varying(255) NOT NULL,
    parent_id bigint NOT NULL,
    type character varying(255) NOT NULL,
    url text NOT NULL,
    preview_url character varying(255),
    "order" integer DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN attachments.parent_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.attachments.parent_type IS 'Тип родительского объекта: context_post, event и др.';


--
-- Name: COLUMN attachments.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.attachments.parent_id IS 'ID родительского объекта';


--
-- Name: COLUMN attachments.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.attachments.type IS 'Тип вложения: image, video, file и др.';


--
-- Name: COLUMN attachments.url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.attachments.url IS 'Ссылка на файл';


--
-- Name: COLUMN attachments.preview_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.attachments.preview_url IS 'Ссылка на превью (если есть)';


--
-- Name: COLUMN attachments."order"; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.attachments."order" IS 'Порядок вложения';


--
-- Name: attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.attachments_id_seq OWNED BY public.attachments.id;


--
-- Name: cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cache (
    key character varying(255) NOT NULL,
    value text NOT NULL,
    expiration integer NOT NULL
);


--
-- Name: cache_locks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cache_locks (
    key character varying(255) NOT NULL,
    owner character varying(255) NOT NULL,
    expiration integer NOT NULL
);


--
-- Name: cities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cities (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    country_code character varying(2),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    location public.geometry(Point,4326) NOT NULL,
    latitude numeric(9,6) GENERATED ALWAYS AS (public.st_y((location)::public.geometry)) STORED,
    longitude numeric(9,6) GENERATED ALWAYS AS (public.st_x((location)::public.geometry)) STORED,
    status character varying(16) DEFAULT 'active'::character varying NOT NULL,
    name_ci text GENERATED ALWAYS AS (lower((name)::text)) STORED
);


--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- Name: communities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.communities (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    city character varying(255),
    street character varying(255),
    house character varying(255),
    avatar_url character varying(255),
    image_url character varying(255),
    last_checked_at timestamp(0) without time zone,
    verification_status character varying(255) DEFAULT 'pending'::character varying,
    is_verified boolean DEFAULT false NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    verification_meta jsonb,
    city_id bigint
);


--
-- Name: COLUMN communities.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.name IS 'Название сообщества';


--
-- Name: COLUMN communities.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.description IS 'Описание сообщества';


--
-- Name: COLUMN communities.city; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.city IS 'Город (опционально)';


--
-- Name: COLUMN communities.street; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.street IS 'Улица';


--
-- Name: COLUMN communities.house; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.house IS 'Дом';


--
-- Name: COLUMN communities.avatar_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.avatar_url IS 'Ссылка на аватар';


--
-- Name: COLUMN communities.image_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.image_url IS 'Доп. изображение или постер';


--
-- Name: COLUMN communities.last_checked_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.last_checked_at IS 'Время последней проверки (парсинг/валидность)';


--
-- Name: COLUMN communities.verification_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.verification_status IS 'Статус проверки/верификации (pending/approved/rejected)';


--
-- Name: COLUMN communities.is_verified; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.communities.is_verified IS 'Признак верификации';


--
-- Name: communities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.communities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: communities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.communities_id_seq OWNED BY public.communities.id;


--
-- Name: community_interest; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_interest (
    community_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN community_interest.community_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.community_interest.community_id IS 'FK на communities.id';


--
-- Name: COLUMN community_interest.interest_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.community_interest.interest_id IS 'FK на interests.id';


--
-- Name: community_social_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.community_social_links (
    id bigint NOT NULL,
    community_id bigint NOT NULL,
    social_network_id bigint NOT NULL,
    external_community_id character varying(128),
    url character varying(512) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    last_verification_id bigint,
    last_checked_at timestamp(0) without time zone,
    last_is_active boolean,
    last_has_events boolean,
    last_kind character varying(16),
    last_hq_city character varying(255),
    last_hq_street character varying(255),
    last_hq_house character varying(255),
    last_hq_confidence numeric(3,2)
);


--
-- Name: COLUMN community_social_links.community_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.community_social_links.community_id IS 'FK на communities.id';


--
-- Name: COLUMN community_social_links.social_network_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.community_social_links.social_network_id IS 'FK на social_networks.id';


--
-- Name: COLUMN community_social_links.external_community_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.community_social_links.external_community_id IS 'ID/slug/username сообщества в соцсети или null для сайтов';


--
-- Name: COLUMN community_social_links.url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.community_social_links.url IS 'Ссылка на профиль сообщества в соцсети или на сайте';


--
-- Name: community_social_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.community_social_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: community_social_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.community_social_links_id_seq OWNED BY public.community_social_links.id;


--
-- Name: context_interactions; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: COLUMN context_interactions.post_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_interactions.post_id IS 'FK на context_posts.id';


--
-- Name: COLUMN context_interactions.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_interactions.user_id IS 'FK на users.id';


--
-- Name: COLUMN context_interactions.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_interactions.type IS 'Тип действия: request, response, flag, comment и др.';


--
-- Name: COLUMN context_interactions.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_interactions.status IS 'Статус действия: active, reviewed, flagged и др.';


--
-- Name: COLUMN context_interactions.message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_interactions.message IS 'Сообщение, комментарий, ответ';


--
-- Name: COLUMN context_interactions.reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_interactions.reason IS 'Причина/категория, если применимо';


--
-- Name: context_interactions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.context_interactions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: context_interactions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.context_interactions_id_seq OWNED BY public.context_interactions.id;


--
-- Name: context_posts; Type: TABLE; Schema: public; Owner: -
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
    updated_at timestamp(0) without time zone,
    social_link_id bigint,
    deleted_at timestamp(0) without time zone
);


--
-- Name: COLUMN context_posts.external_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.external_id IS 'ID исходного поста VK/TG/сайт';


--
-- Name: COLUMN context_posts.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.source IS 'vk, tg, site и др.';


--
-- Name: COLUMN context_posts.author_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.author_id IS 'ID автора (user/community/external)';


--
-- Name: COLUMN context_posts.author_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.author_type IS 'user, community, external';


--
-- Name: COLUMN context_posts.community_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.community_id IS 'FK на communities.id';


--
-- Name: COLUMN context_posts.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.status IS 'active, flagged, hidden и др.';


--
-- Name: COLUMN context_posts.social_link_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.context_posts.social_link_id IS 'FK на community_social_links.id';


--
-- Name: context_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.context_posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: context_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.context_posts_id_seq OWNED BY public.context_posts.id;


--
-- Name: error_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.error_logs (
    id bigint NOT NULL,
    type character varying(64) NOT NULL,
    community_id bigint,
    community_social_link_id bigint,
    job character varying(128),
    error_text text NOT NULL,
    error_code character varying(32),
    logged_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resolved boolean DEFAULT false NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    meta jsonb
);


--
-- Name: COLUMN error_logs.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.id IS 'Primary key';


--
-- Name: COLUMN error_logs.type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.type IS 'Тип ошибки: vk_api, job_error, frozen, ml_error и др.';


--
-- Name: COLUMN error_logs.community_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.community_id IS 'ID сообщества, если применимо';


--
-- Name: COLUMN error_logs.community_social_link_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.community_social_link_id IS 'ID ссылки источника, если применимо';


--
-- Name: COLUMN error_logs.job; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.job IS 'Класс/имя задания (job), в котором возникла ошибка';


--
-- Name: COLUMN error_logs.error_text; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.error_text IS 'Текст ошибки';


--
-- Name: COLUMN error_logs.error_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.error_code IS 'Код ошибки, если есть';


--
-- Name: COLUMN error_logs.logged_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.logged_at IS 'Время записи';


--
-- Name: COLUMN error_logs.resolved; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.resolved IS 'Ошибка решена/неактуальна';


--
-- Name: COLUMN error_logs.meta; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.error_logs.meta IS 'Дополнительные данные/контекст';


--
-- Name: error_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.error_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: error_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.error_logs_id_seq OWNED BY public.error_logs.id;


--
-- Name: event_attendees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_attendees (
    event_id bigint NOT NULL,
    user_id bigint NOT NULL,
    status character varying(255) DEFAULT 'going'::character varying NOT NULL,
    joined_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN event_attendees.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.event_attendees.event_id IS 'FK на events.id';


--
-- Name: COLUMN event_attendees.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.event_attendees.user_id IS 'FK на users.id';


--
-- Name: COLUMN event_attendees.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.event_attendees.status IS 'Статус участия: going, interested, rejected и др.';


--
-- Name: COLUMN event_attendees.joined_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.event_attendees.joined_at IS 'Время присоединения';


--
-- Name: event_interest; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_interest (
    event_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN event_interest.event_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.event_interest.event_id IS 'FK на events.id';


--
-- Name: COLUMN event_interest.interest_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.event_interest.interest_id IS 'FK на interests.id';


--
-- Name: event_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_sources (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    social_link_id bigint NOT NULL,
    context_post_id bigint,
    source text NOT NULL,
    post_external_id text NOT NULL,
    external_url text,
    published_at timestamp(0) with time zone,
    images json DEFAULT '[]'::json NOT NULL,
    meta json,
    generated_link text,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: event_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_sources_id_seq OWNED BY public.event_sources.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
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
    location public.geometry(Point,4326),
    latitude numeric(9,6) GENERATED ALWAYS AS (public.st_y((location)::public.geometry)) STORED,
    longitude numeric(9,6) GENERATED ALWAYS AS (public.st_x((location)::public.geometry)) STORED,
    lat_round numeric(9,3) GENERATED ALWAYS AS (
CASE
    WHEN (location IS NULL) THEN NULL::numeric
    ELSE round((public.st_y(location))::numeric, 3)
END) STORED,
    lon_round numeric(9,3) GENERATED ALWAYS AS (
CASE
    WHEN (location IS NULL) THEN NULL::numeric
    ELSE round((public.st_x(location))::numeric, 3)
END) STORED,
    dedup_key character varying(66),
    house_fias_id character varying(36),
    city_id bigint
);


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: failed_jobs; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: failed_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.failed_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: failed_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.failed_jobs_id_seq OWNED BY public.failed_jobs.id;


--
-- Name: interest_aliases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interest_aliases (
    id bigint NOT NULL,
    interest_id bigint NOT NULL,
    alias character varying(64) NOT NULL,
    locale character varying(8),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN interest_aliases.alias; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_aliases.alias IS 'Синоним / альтернативный ярлык';


--
-- Name: COLUMN interest_aliases.locale; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_aliases.locale IS 'ru/en/... (опционально)';


--
-- Name: interest_aliases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interest_aliases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interest_aliases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interest_aliases_id_seq OWNED BY public.interest_aliases.id;


--
-- Name: interest_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interest_links (
    parent_type character varying(255) NOT NULL,
    parent_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN interest_links.parent_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_links.parent_type IS 'Тип объекта: context_post, event и др.';


--
-- Name: COLUMN interest_links.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_links.parent_id IS 'ID объекта';


--
-- Name: COLUMN interest_links.interest_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_links.interest_id IS 'FK на interests.id';


--
-- Name: interest_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interest_relations (
    id bigint NOT NULL,
    parent_interest_id bigint NOT NULL,
    child_interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN interest_relations.parent_interest_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_relations.parent_interest_id IS 'FK на interests.id (родитель)';


--
-- Name: COLUMN interest_relations.child_interest_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_relations.child_interest_id IS 'FK на interests.id (дочерний)';


--
-- Name: interest_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interest_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interest_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interest_relations_id_seq OWNED BY public.interest_relations.id;


--
-- Name: interest_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interest_user (
    user_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN interest_user.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_user.user_id IS 'FK на users.id';


--
-- Name: COLUMN interest_user.interest_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interest_user.interest_id IS 'FK на interests.id';


--
-- Name: interests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interests (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    parent_id bigint,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone,
    slug character varying(64) NOT NULL
);


--
-- Name: COLUMN interests.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interests.name IS 'Название интереса';


--
-- Name: COLUMN interests.parent_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.interests.parent_id IS 'FK на interests.id, для дерева интересов';


--
-- Name: interests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interests_id_seq OWNED BY public.interests.id;


--
-- Name: job_batches; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.jobs_id_seq OWNED BY public.jobs.id;


--
-- Name: llm_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_jobs (
    id bigint NOT NULL,
    type character varying(32) DEFAULT 'chat'::character varying NOT NULL,
    status character varying(24) DEFAULT 'pending'::character varying NOT NULL,
    context_post_id bigint,
    input jsonb,
    options jsonb,
    result jsonb,
    error_code integer,
    error_message character varying(1024),
    started_at timestamp(0) without time zone,
    finished_at timestamp(0) without time zone,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: llm_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_jobs_id_seq OWNED BY public.llm_jobs.id;


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    migration character varying(255) NOT NULL,
    batch integer NOT NULL
);


--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.migrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: migrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.migrations_id_seq OWNED BY public.migrations.id;


--
-- Name: model_has_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.model_has_permissions (
    permission_id bigint NOT NULL,
    model_type character varying(255) NOT NULL,
    model_id bigint NOT NULL
);


--
-- Name: model_has_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.model_has_roles (
    role_id bigint NOT NULL,
    model_type character varying(255) NOT NULL,
    model_id bigint NOT NULL
);


--
-- Name: parsing_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parsing_statuses (
    id bigint NOT NULL,
    community_social_link_id bigint NOT NULL,
    is_frozen boolean DEFAULT false NOT NULL,
    frozen_reason character varying(64),
    unfreeze_at timestamp(0) without time zone,
    last_error text,
    last_error_code character varying(16),
    last_success_at timestamp(0) without time zone,
    total_failures integer DEFAULT 0 NOT NULL,
    retry_count integer DEFAULT 0 NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN parsing_statuses.id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.id IS 'Primary key: статус парсинга для каждой community_social_link';


--
-- Name: COLUMN parsing_statuses.community_social_link_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.community_social_link_id IS 'FK на community_social_links.id — источник парсинга';


--
-- Name: COLUMN parsing_statuses.is_frozen; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.is_frozen IS 'Флаг: источник заморожен для парсинга (лимиты, ошибки, капча)';


--
-- Name: COLUMN parsing_statuses.frozen_reason; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.frozen_reason IS 'Причина заморозки: rate_limit, ban, captcha, error, manual';


--
-- Name: COLUMN parsing_statuses.unfreeze_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.unfreeze_at IS 'Время автоматического размораживания';


--
-- Name: COLUMN parsing_statuses.last_error; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.last_error IS 'Текст последней ошибки';


--
-- Name: COLUMN parsing_statuses.last_error_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.last_error_code IS 'Код ошибки (429, 403, 500, timeout и др.)';


--
-- Name: COLUMN parsing_statuses.last_success_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.last_success_at IS 'Время последнего успешного парсинга';


--
-- Name: COLUMN parsing_statuses.total_failures; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.total_failures IS 'Число неудачных попыток подряд';


--
-- Name: COLUMN parsing_statuses.retry_count; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.parsing_statuses.retry_count IS 'Количество подряд ретраев после последнего успеха';


--
-- Name: parsing_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parsing_statuses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parsing_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parsing_statuses_id_seq OWNED BY public.parsing_statuses.id;


--
-- Name: password_reset_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.password_reset_tokens (
    email character varying(255) NOT NULL,
    token character varying(255) NOT NULL,
    created_at timestamp(0) without time zone
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    guard_name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: personal_access_tokens; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.personal_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: personal_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.personal_access_tokens_id_seq OWNED BY public.personal_access_tokens.id;


--
-- Name: role_has_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_has_permissions (
    permission_id bigint NOT NULL,
    role_id bigint NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id bigint NOT NULL,
    name character varying(255) NOT NULL,
    guard_name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: roles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.roles_id_seq OWNED BY public.roles.id;


--
-- Name: seeders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.seeders (
    id bigint NOT NULL,
    seeder_name character varying(255) NOT NULL,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: seeders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.seeders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: seeders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.seeders_id_seq OWNED BY public.seeders.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id character varying(255) NOT NULL,
    user_id bigint,
    ip_address character varying(45),
    user_agent text,
    payload text NOT NULL,
    last_activity integer NOT NULL
);


--
-- Name: social_link_verifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_link_verifications (
    id bigint NOT NULL,
    community_id bigint NOT NULL,
    community_social_link_id bigint NOT NULL,
    social_network_id bigint NOT NULL,
    checked_at timestamp(0) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    status character varying(16) DEFAULT 'ok'::character varying NOT NULL,
    latency_ms integer,
    model character varying(64),
    prompt_version integer DEFAULT 1 NOT NULL,
    error_code character varying(64),
    error_message text,
    is_active boolean,
    has_events_posts boolean,
    activity_score numeric(3,2),
    events_score numeric(3,2),
    kind character varying(16),
    has_fixed_place boolean,
    hq_city character varying(255),
    hq_street character varying(255),
    hq_house character varying(255),
    hq_confidence numeric(3,2),
    examples jsonb,
    events_locations jsonb,
    raw jsonb,
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: social_link_verifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.social_link_verifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: social_link_verifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.social_link_verifications_id_seq OWNED BY public.social_link_verifications.id;


--
-- Name: social_networks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.social_networks (
    id bigint NOT NULL,
    name character varying(64) NOT NULL,
    slug character varying(32) NOT NULL,
    icon character varying(255),
    url_mask character varying(255),
    created_at timestamp(0) without time zone,
    updated_at timestamp(0) without time zone
);


--
-- Name: COLUMN social_networks.name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.social_networks.name IS 'Название соцсети (VK, Telegram, Instagram, ...)';


--
-- Name: COLUMN social_networks.slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.social_networks.slug IS 'Слаг: vk, telegram, instagram и др.';


--
-- Name: COLUMN social_networks.icon; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.social_networks.icon IS 'Иконка/emoji или URL';


--
-- Name: COLUMN social_networks.url_mask; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.social_networks.url_mask IS 'Шаблон для генерации ссылок';


--
-- Name: social_networks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.social_networks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: social_networks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.social_networks_id_seq OWNED BY public.social_networks.id;


--
-- Name: telegram_users; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: COLUMN telegram_users.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.user_id IS 'FK на users.id, опционально';


--
-- Name: COLUMN telegram_users.telegram_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.telegram_id IS 'Telegram user ID (уникальный)';


--
-- Name: COLUMN telegram_users.telegram_username; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.telegram_username IS 'username в Telegram';


--
-- Name: COLUMN telegram_users.first_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.first_name IS 'Имя пользователя в Telegram';


--
-- Name: COLUMN telegram_users.last_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.last_name IS 'Фамилия пользователя в Telegram';


--
-- Name: COLUMN telegram_users.language_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.language_code IS 'Язык пользователя';


--
-- Name: COLUMN telegram_users.chat_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.chat_id IS 'Активный chat_id Telegram';


--
-- Name: COLUMN telegram_users.is_bot; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.is_bot IS 'Это бот-пользователь';


--
-- Name: COLUMN telegram_users.registered_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.registered_at IS 'Первое посещение';


--
-- Name: COLUMN telegram_users.last_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.telegram_users.last_active IS 'Последняя активность';


--
-- Name: telegram_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.telegram_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: telegram_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.telegram_users_id_seq OWNED BY public.telegram_users.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
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


--
-- Name: COLUMN users.avatar_url; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.avatar_url IS 'Ссылка на аватар пользователя';


--
-- Name: COLUMN users.bio; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.bio IS 'Коротко о себе';


--
-- Name: COLUMN users.deleted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.deleted_at IS 'Мягкое удаление';


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments ALTER COLUMN id SET DEFAULT nextval('public.attachments_id_seq'::regclass);


--
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- Name: communities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communities ALTER COLUMN id SET DEFAULT nextval('public.communities_id_seq'::regclass);


--
-- Name: community_social_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_social_links ALTER COLUMN id SET DEFAULT nextval('public.community_social_links_id_seq'::regclass);


--
-- Name: context_interactions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_interactions ALTER COLUMN id SET DEFAULT nextval('public.context_interactions_id_seq'::regclass);


--
-- Name: context_posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_posts ALTER COLUMN id SET DEFAULT nextval('public.context_posts_id_seq'::regclass);


--
-- Name: error_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_logs ALTER COLUMN id SET DEFAULT nextval('public.error_logs_id_seq'::regclass);


--
-- Name: event_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources ALTER COLUMN id SET DEFAULT nextval('public.event_sources_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: failed_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.failed_jobs ALTER COLUMN id SET DEFAULT nextval('public.failed_jobs_id_seq'::regclass);


--
-- Name: interest_aliases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_aliases ALTER COLUMN id SET DEFAULT nextval('public.interest_aliases_id_seq'::regclass);


--
-- Name: interest_relations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_relations ALTER COLUMN id SET DEFAULT nextval('public.interest_relations_id_seq'::regclass);


--
-- Name: interests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests ALTER COLUMN id SET DEFAULT nextval('public.interests_id_seq'::regclass);


--
-- Name: jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs ALTER COLUMN id SET DEFAULT nextval('public.jobs_id_seq'::regclass);


--
-- Name: llm_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_jobs ALTER COLUMN id SET DEFAULT nextval('public.llm_jobs_id_seq'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: parsing_statuses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parsing_statuses ALTER COLUMN id SET DEFAULT nextval('public.parsing_statuses_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: personal_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.personal_access_tokens_id_seq'::regclass);


--
-- Name: roles id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles ALTER COLUMN id SET DEFAULT nextval('public.roles_id_seq'::regclass);


--
-- Name: seeders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seeders ALTER COLUMN id SET DEFAULT nextval('public.seeders_id_seq'::regclass);


--
-- Name: social_link_verifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_link_verifications ALTER COLUMN id SET DEFAULT nextval('public.social_link_verifications_id_seq'::regclass);


--
-- Name: social_networks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_networks ALTER COLUMN id SET DEFAULT nextval('public.social_networks_id_seq'::regclass);


--
-- Name: telegram_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telegram_users ALTER COLUMN id SET DEFAULT nextval('public.telegram_users_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: cache_locks cache_locks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cache_locks
    ADD CONSTRAINT cache_locks_pkey PRIMARY KEY (key);


--
-- Name: cache cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cache
    ADD CONSTRAINT cache_pkey PRIMARY KEY (key);


--
-- Name: cities cities_country_name_ci_uniq; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_country_name_ci_uniq UNIQUE (country_code, name_ci);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: communities communities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_pkey PRIMARY KEY (id);


--
-- Name: community_interest community_interest_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_interest
    ADD CONSTRAINT community_interest_pkey PRIMARY KEY (community_id, interest_id);


--
-- Name: community_social_links community_network_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_network_unique UNIQUE (community_id, social_network_id);


--
-- Name: community_social_links community_social_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_pkey PRIMARY KEY (id);


--
-- Name: context_interactions context_interactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_interactions
    ADD CONSTRAINT context_interactions_pkey PRIMARY KEY (id);


--
-- Name: context_posts context_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_posts
    ADD CONSTRAINT context_posts_pkey PRIMARY KEY (id);


--
-- Name: error_logs error_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_logs
    ADD CONSTRAINT error_logs_pkey PRIMARY KEY (id);


--
-- Name: event_attendees event_attendees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_attendees
    ADD CONSTRAINT event_attendees_pkey PRIMARY KEY (event_id, user_id);


--
-- Name: event_interest event_interest_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_interest
    ADD CONSTRAINT event_interest_pkey PRIMARY KEY (event_id, interest_id);


--
-- Name: event_sources event_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_pkey PRIMARY KEY (id);


--
-- Name: failed_jobs failed_jobs_uuid_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.failed_jobs
    ADD CONSTRAINT failed_jobs_uuid_unique UNIQUE (uuid);


--
-- Name: interest_aliases interest_aliases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_aliases
    ADD CONSTRAINT interest_aliases_pkey PRIMARY KEY (id);


--
-- Name: interest_links interest_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_links
    ADD CONSTRAINT interest_links_pkey PRIMARY KEY (parent_type, parent_id, interest_id);


--
-- Name: interest_relations interest_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT interest_relations_pkey PRIMARY KEY (id);


--
-- Name: interest_user interest_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_user
    ADD CONSTRAINT interest_user_pkey PRIMARY KEY (user_id, interest_id);


--
-- Name: interests interests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests
    ADD CONSTRAINT interests_pkey PRIMARY KEY (id);


--
-- Name: job_batches job_batches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_batches
    ADD CONSTRAINT job_batches_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: llm_jobs llm_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_jobs
    ADD CONSTRAINT llm_jobs_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: model_has_permissions model_has_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_has_permissions
    ADD CONSTRAINT model_has_permissions_pkey PRIMARY KEY (permission_id, model_id, model_type);


--
-- Name: model_has_roles model_has_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_has_roles
    ADD CONSTRAINT model_has_roles_pkey PRIMARY KEY (role_id, model_id, model_type);


--
-- Name: parsing_statuses parsing_statuses_link_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parsing_statuses
    ADD CONSTRAINT parsing_statuses_link_unique UNIQUE (community_social_link_id);


--
-- Name: parsing_statuses parsing_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parsing_statuses
    ADD CONSTRAINT parsing_statuses_pkey PRIMARY KEY (id);


--
-- Name: password_reset_tokens password_reset_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.password_reset_tokens
    ADD CONSTRAINT password_reset_tokens_pkey PRIMARY KEY (email);


--
-- Name: permissions permissions_name_guard_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_name_guard_name_unique UNIQUE (name, guard_name);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: personal_access_tokens personal_access_tokens_token_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.personal_access_tokens
    ADD CONSTRAINT personal_access_tokens_token_unique UNIQUE (token);


--
-- Name: role_has_permissions role_has_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_has_permissions
    ADD CONSTRAINT role_has_permissions_pkey PRIMARY KEY (permission_id, role_id);


--
-- Name: roles roles_name_guard_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_guard_name_unique UNIQUE (name, guard_name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: seeders seeders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seeders
    ADD CONSTRAINT seeders_pkey PRIMARY KEY (id);


--
-- Name: seeders seeders_seeder_name_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.seeders
    ADD CONSTRAINT seeders_seeder_name_unique UNIQUE (seeder_name);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: social_link_verifications social_link_verifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_link_verifications
    ADD CONSTRAINT social_link_verifications_pkey PRIMARY KEY (id);


--
-- Name: social_networks social_networks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_networks
    ADD CONSTRAINT social_networks_pkey PRIMARY KEY (id);


--
-- Name: social_networks social_networks_slug_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_networks
    ADD CONSTRAINT social_networks_slug_unique UNIQUE (slug);


--
-- Name: telegram_users telegram_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telegram_users
    ADD CONSTRAINT telegram_users_pkey PRIMARY KEY (id);


--
-- Name: telegram_users telegram_users_telegram_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telegram_users
    ADD CONSTRAINT telegram_users_telegram_id_unique UNIQUE (telegram_id);


--
-- Name: interest_relations unique_interest_relation; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT unique_interest_relation UNIQUE (parent_interest_id, child_interest_id);


--
-- Name: event_sources uq_event_sources_source_post_event; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT uq_event_sources_source_post_event UNIQUE (source, post_external_id, event_id);


--
-- Name: users users_email_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_unique UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: attachments_parent_type_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachments_parent_type_parent_id_index ON public.attachments USING btree (parent_type, parent_id);


--
-- Name: attachments_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX attachments_type_index ON public.attachments USING btree (type);


--
-- Name: cities_location_gix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_location_gix ON public.cities USING gist (location);


--
-- Name: cities_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX cities_status_idx ON public.cities USING btree (status);


--
-- Name: communities_city_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX communities_city_id_idx ON public.communities USING btree (city_id);


--
-- Name: communities_city_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX communities_city_index ON public.communities USING btree (city);


--
-- Name: communities_is_verified_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX communities_is_verified_index ON public.communities USING btree (is_verified);


--
-- Name: communities_verification_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX communities_verification_status_index ON public.communities USING btree (verification_status);


--
-- Name: community_social_links_community_id_social_network_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX community_social_links_community_id_social_network_id_index ON public.community_social_links USING btree (community_id, social_network_id);


--
-- Name: community_social_links_external_community_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX community_social_links_external_community_id_index ON public.community_social_links USING btree (external_community_id);


--
-- Name: community_social_links_last_checked_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX community_social_links_last_checked_at_idx ON public.community_social_links USING btree (last_checked_at);


--
-- Name: context_interactions_post_id_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_interactions_post_id_user_id_index ON public.context_interactions USING btree (post_id, user_id);


--
-- Name: context_interactions_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_interactions_status_index ON public.context_interactions USING btree (status);


--
-- Name: context_interactions_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_interactions_type_index ON public.context_interactions USING btree (type);


--
-- Name: context_posts_external_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_posts_external_id_index ON public.context_posts USING btree (external_id);


--
-- Name: context_posts_published_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_posts_published_at_index ON public.context_posts USING btree (published_at);


--
-- Name: context_posts_social_link_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_posts_social_link_id_index ON public.context_posts USING btree (social_link_id);


--
-- Name: context_posts_source_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_posts_source_index ON public.context_posts USING btree (source);


--
-- Name: context_posts_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_posts_status_index ON public.context_posts USING btree (status);


--
-- Name: error_logs_community_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX error_logs_community_id_index ON public.error_logs USING btree (community_id);


--
-- Name: error_logs_community_social_link_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX error_logs_community_social_link_id_index ON public.error_logs USING btree (community_social_link_id);


--
-- Name: error_logs_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX error_logs_type_index ON public.error_logs USING btree (type);


--
-- Name: error_logs_type_job_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX error_logs_type_job_index ON public.error_logs USING btree (type, job);


--
-- Name: event_attendees_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX event_attendees_status_index ON public.event_attendees USING btree (status);


--
-- Name: event_interest_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX event_interest_unique ON public.event_interest USING btree (event_id, interest_id);


--
-- Name: events_city_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_city_id_idx ON public.events USING btree (city_id);


--
-- Name: events_city_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_city_index ON public.events USING btree (city);


--
-- Name: events_location_gix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_location_gix ON public.events USING gist (location);


--
-- Name: events_start_time_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_start_time_index ON public.events USING btree (start_time);


--
-- Name: events_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_status_index ON public.events USING btree (status);


--
-- Name: idx_attachments_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attachments_parent ON public.attachments USING btree (parent_type, parent_id);


--
-- Name: idx_communities_desc_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_desc_trgm ON public.communities USING gin (lower(description) public.gin_trgm_ops);


--
-- Name: idx_communities_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_name_trgm ON public.communities USING gin (lower((name)::text) public.gin_trgm_ops);


--
-- Name: idx_communities_verification_meta_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_communities_verification_meta_gin ON public.communities USING gin (verification_meta);


--
-- Name: idx_event_sources_context_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_sources_context_post_id ON public.event_sources USING btree (context_post_id);


--
-- Name: idx_event_sources_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_sources_event_id ON public.event_sources USING btree (event_id);


--
-- Name: idx_event_sources_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_sources_published_at ON public.event_sources USING btree (published_at);


--
-- Name: idx_events_desc_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_desc_trgm ON public.events USING gin (lower(description) public.gin_trgm_ops);


--
-- Name: idx_events_original_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_original_post_id ON public.events USING btree (original_post_id);


--
-- Name: idx_events_start_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_start_time ON public.events USING btree (start_time);


--
-- Name: idx_events_time_geo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_time_geo ON public.events USING btree (start_time, lat_round, lon_round) WHERE ((lat_round IS NOT NULL) AND (lon_round IS NOT NULL) AND (deleted_at IS NULL));


--
-- Name: idx_events_title_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_events_title_trgm ON public.events USING gin (lower((title)::text) public.gin_trgm_ops);


--
-- Name: idx_interests_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_interests_name_trgm ON public.interests USING gin (lower((name)::text) public.gin_trgm_ops);


--
-- Name: idx_slv_comm_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_slv_comm_time ON public.social_link_verifications USING btree (community_id, checked_at);


--
-- Name: idx_slv_link_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_slv_link_time ON public.social_link_verifications USING btree (community_social_link_id, checked_at);


--
-- Name: idx_slv_raw_gin; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_slv_raw_gin ON public.social_link_verifications USING gin (raw);


--
-- Name: interest_aliases_alias_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX interest_aliases_alias_unique ON public.interest_aliases USING btree (lower((alias)::text));


--
-- Name: interest_aliases_interest_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interest_aliases_interest_id_index ON public.interest_aliases USING btree (interest_id);


--
-- Name: interest_links_parent_type_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interest_links_parent_type_parent_id_index ON public.interest_links USING btree (parent_type, parent_id);


--
-- Name: interest_relations_parent_interest_id_child_interest_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interest_relations_parent_interest_id_child_interest_id_index ON public.interest_relations USING btree (parent_interest_id, child_interest_id);


--
-- Name: interests_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interests_name_idx ON public.interests USING btree (lower((name)::text));


--
-- Name: interests_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interests_name_index ON public.interests USING btree (name);


--
-- Name: interests_parent_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX interests_parent_id_index ON public.interests USING btree (parent_id);


--
-- Name: interests_slug_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX interests_slug_unique ON public.interests USING btree (lower((slug)::text));


--
-- Name: jobs_queue_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX jobs_queue_index ON public.jobs USING btree (queue);


--
-- Name: llm_jobs_context_post_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX llm_jobs_context_post_id_index ON public.llm_jobs USING btree (context_post_id);


--
-- Name: llm_jobs_status_created_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX llm_jobs_status_created_at_index ON public.llm_jobs USING btree (status, created_at);


--
-- Name: model_has_permissions_model_id_model_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX model_has_permissions_model_id_model_type_index ON public.model_has_permissions USING btree (model_id, model_type);


--
-- Name: model_has_roles_model_id_model_type_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX model_has_roles_model_id_model_type_index ON public.model_has_roles USING btree (model_id, model_type);


--
-- Name: parsing_statuses_frozen_unfreeze_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX parsing_statuses_frozen_unfreeze_index ON public.parsing_statuses USING btree (is_frozen, unfreeze_at);


--
-- Name: personal_access_tokens_tokenable_type_tokenable_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX personal_access_tokens_tokenable_type_tokenable_id_index ON public.personal_access_tokens USING btree (tokenable_type, tokenable_id);


--
-- Name: sessions_last_activity_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_last_activity_index ON public.sessions USING btree (last_activity);


--
-- Name: sessions_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_user_id_index ON public.sessions USING btree (user_id);


--
-- Name: social_networks_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_networks_name_index ON public.social_networks USING btree (name);


--
-- Name: social_networks_slug_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX social_networks_slug_index ON public.social_networks USING btree (slug);


--
-- Name: telegram_users_last_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX telegram_users_last_active_index ON public.telegram_users USING btree (last_active);


--
-- Name: telegram_users_telegram_username_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX telegram_users_telegram_username_index ON public.telegram_users USING btree (telegram_username);


--
-- Name: uniq_events_dedup_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uniq_events_dedup_active ON public.events USING btree (dedup_key) WHERE (deleted_at IS NULL);


--
-- Name: communities communities_city_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.communities
    ADD CONSTRAINT communities_city_id_foreign FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE SET NULL;


--
-- Name: community_interest community_interest_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_interest
    ADD CONSTRAINT community_interest_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_interest community_interest_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_interest
    ADD CONSTRAINT community_interest_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: community_social_links community_social_links_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: community_social_links community_social_links_last_verification_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_last_verification_id_foreign FOREIGN KEY (last_verification_id) REFERENCES public.social_link_verifications(id) ON DELETE SET NULL;


--
-- Name: community_social_links community_social_links_social_network_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.community_social_links
    ADD CONSTRAINT community_social_links_social_network_id_foreign FOREIGN KEY (social_network_id) REFERENCES public.social_networks(id) ON DELETE CASCADE;


--
-- Name: context_interactions context_interactions_post_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_interactions
    ADD CONSTRAINT context_interactions_post_id_foreign FOREIGN KEY (post_id) REFERENCES public.context_posts(id) ON DELETE CASCADE;


--
-- Name: context_interactions context_interactions_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_interactions
    ADD CONSTRAINT context_interactions_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: context_posts context_posts_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_posts
    ADD CONSTRAINT context_posts_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE SET NULL;


--
-- Name: context_posts context_posts_social_link_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_posts
    ADD CONSTRAINT context_posts_social_link_id_foreign FOREIGN KEY (social_link_id) REFERENCES public.community_social_links(id) ON DELETE SET NULL;


--
-- Name: event_attendees event_attendees_event_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_attendees
    ADD CONSTRAINT event_attendees_event_id_foreign FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_attendees event_attendees_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_attendees
    ADD CONSTRAINT event_attendees_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: event_interest event_interest_event_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_interest
    ADD CONSTRAINT event_interest_event_id_foreign FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_interest event_interest_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_interest
    ADD CONSTRAINT event_interest_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: event_sources event_sources_context_post_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_context_post_id_foreign FOREIGN KEY (context_post_id) REFERENCES public.context_posts(id) ON DELETE SET NULL;


--
-- Name: event_sources event_sources_event_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_event_id_foreign FOREIGN KEY (event_id) REFERENCES public.events(id) ON DELETE CASCADE;


--
-- Name: event_sources event_sources_social_link_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_sources
    ADD CONSTRAINT event_sources_social_link_id_foreign FOREIGN KEY (social_link_id) REFERENCES public.community_social_links(id) ON DELETE CASCADE;


--
-- Name: events events_city_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_city_id_foreign FOREIGN KEY (city_id) REFERENCES public.cities(id) ON DELETE SET NULL;


--
-- Name: events events_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: events events_original_post_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_original_post_id_foreign FOREIGN KEY (original_post_id) REFERENCES public.context_posts(id) ON DELETE SET NULL;


--
-- Name: interest_aliases interest_aliases_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_aliases
    ADD CONSTRAINT interest_aliases_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_links interest_links_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_links
    ADD CONSTRAINT interest_links_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_relations interest_relations_child_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT interest_relations_child_interest_id_foreign FOREIGN KEY (child_interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_relations interest_relations_parent_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_relations
    ADD CONSTRAINT interest_relations_parent_interest_id_foreign FOREIGN KEY (parent_interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_user interest_user_interest_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_user
    ADD CONSTRAINT interest_user_interest_id_foreign FOREIGN KEY (interest_id) REFERENCES public.interests(id) ON DELETE CASCADE;


--
-- Name: interest_user interest_user_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interest_user
    ADD CONSTRAINT interest_user_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: interests interests_parent_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests
    ADD CONSTRAINT interests_parent_id_foreign FOREIGN KEY (parent_id) REFERENCES public.interests(id) ON DELETE SET NULL;


--
-- Name: llm_jobs llm_jobs_context_post_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_jobs
    ADD CONSTRAINT llm_jobs_context_post_id_foreign FOREIGN KEY (context_post_id) REFERENCES public.context_posts(id) ON DELETE SET NULL;


--
-- Name: model_has_permissions model_has_permissions_permission_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_has_permissions
    ADD CONSTRAINT model_has_permissions_permission_id_foreign FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: model_has_roles model_has_roles_role_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.model_has_roles
    ADD CONSTRAINT model_has_roles_role_id_foreign FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: parsing_statuses parsing_statuses_link_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parsing_statuses
    ADD CONSTRAINT parsing_statuses_link_fk FOREIGN KEY (community_social_link_id) REFERENCES public.community_social_links(id) ON DELETE CASCADE;


--
-- Name: role_has_permissions role_has_permissions_permission_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_has_permissions
    ADD CONSTRAINT role_has_permissions_permission_id_foreign FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_has_permissions role_has_permissions_role_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_has_permissions
    ADD CONSTRAINT role_has_permissions_role_id_foreign FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: social_link_verifications social_link_verifications_community_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_link_verifications
    ADD CONSTRAINT social_link_verifications_community_id_foreign FOREIGN KEY (community_id) REFERENCES public.communities(id) ON DELETE CASCADE;


--
-- Name: social_link_verifications social_link_verifications_community_social_link_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_link_verifications
    ADD CONSTRAINT social_link_verifications_community_social_link_id_foreign FOREIGN KEY (community_social_link_id) REFERENCES public.community_social_links(id) ON DELETE CASCADE;


--
-- Name: social_link_verifications social_link_verifications_social_network_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.social_link_verifications
    ADD CONSTRAINT social_link_verifications_social_network_id_foreign FOREIGN KEY (social_network_id) REFERENCES public.social_networks(id) ON DELETE CASCADE;


--
-- Name: telegram_users telegram_users_user_id_foreign; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.telegram_users
    ADD CONSTRAINT telegram_users_user_id_foreign FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

