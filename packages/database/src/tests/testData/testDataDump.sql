--
-- PostgreSQL database dump
--

-- Dumped from database version 11.3
-- Dumped by pg_dump version 11.3

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
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


--
-- Name: data_source_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.data_source_type AS ENUM (
    'dataElement',
    'dataGroup'
);


--
-- Name: disaster_event_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.disaster_event_type AS ENUM (
    'start',
    'end',
    'resolve'
);


--
-- Name: disaster_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.disaster_type AS ENUM (
    'cyclone',
    'eruption',
    'earthquake',
    'tsunami',
    'flood'
);


--
-- Name: entity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.entity_type AS ENUM (
    'world',
    'project',
    'country',
    'district',
    'sub_district',
    'facility',
    'village',
    'case',
    'case_contact',
    'disaster',
    'school',
    'catchment',
    'sub_catchment',
    'field_station',
    'city',
    'individual'
);


--
-- Name: service_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.service_type AS ENUM (
    'dhis',
    'tupaia',
    'indicator',
    'weather'
);


--
-- Name: verified_email; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.verified_email AS ENUM (
    'unverified',
    'new_user',
    'verified'
);


--
-- Name: generate_object_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_object_id() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
        DECLARE
            time_component bigint;
            machine_id bigint := FLOOR(random() * 16777215);
            process_id bigint;
            seq_id bigint := FLOOR(random() * 16777215);
            result varchar:= '';
        BEGIN
            SELECT FLOOR(EXTRACT(EPOCH FROM clock_timestamp())) INTO time_component;
            SELECT pg_backend_pid() INTO process_id;

            result := result || lpad(to_hex(time_component), 8, '0');
            result := result || lpad(to_hex(machine_id), 6, '0');
            result := result || lpad(to_hex(process_id), 4, '0');
            result := result || lpad(to_hex(seq_id), 6, '0');
            RETURN result;
        END;
      $$;


--
-- Name: immutable_table(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.immutable_table() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF TG_OP = 'UPDATE' AND OLD <> NEW THEN
          RAISE EXCEPTION 'Cannot update immutable table';
        END IF;
      END
    $$;


--
-- Name: notification(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    DECLARE
    new_json_record JSONB;
    old_json_record JSONB;
    record_id TEXT;
    change_type TEXT;
    BEGIN

    -- if nothing has changed, no need to trigger a notification
    IF TG_OP = 'UPDATE' AND OLD = NEW THEN
      RETURN NULL;
    END IF;

    -- set the change_type from the less readable TG_OP
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
      change_type := 'update';
    ELSE
      change_type := 'delete';
    END IF;

    -- set up the old and new records
    IF TG_OP <> 'INSERT' THEN
      old_json_record := public.scrub_geo_data(
        to_jsonb(OLD),
        TG_TABLE_NAME
      );
    END IF;
    IF TG_OP <> 'DELETE' THEN
      new_json_record := public.scrub_geo_data(
        to_jsonb(NEW),
        TG_TABLE_NAME
      );
    END IF;

    IF change_type = 'update' THEN
      record_id := NEW.id;
    ELSE
      record_id := OLD.id;
    END IF;

    -- publish change notification
    PERFORM pg_notify(
      'change',
      json_build_object(
        'record_type',
        TG_TABLE_NAME,
        'record_id',
        record_id,
        'type',
        change_type,
        'old_record',
        old_json_record,
        'new_record',
        new_json_record
      )::text
    );

    -- return the appropriate record to allow the trigger to pass
    IF change_type = 'update' THEN
      RETURN NEW;
    ELSE
      RETURN OLD;
    END IF;

    END;
    $$;


--
-- Name: schema_change_notification(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.schema_change_notification() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
  PERFORM pg_notify('schema_change', 'schema_change');
  END;
  $$;


--
-- Name: scrub_geo_data(jsonb, name); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.scrub_geo_data(current_record jsonb DEFAULT NULL::jsonb, tg_table_name name DEFAULT NULL::name) RETURNS json
    LANGUAGE plpgsql
    AS $$
    DECLARE
      geo_entities RECORD;
    BEGIN
      IF current_record IS NULL THEN
        RETURN '{}';
      END IF;
      FOR geo_entities IN
        SELECT f_table_name, f_geography_column
        FROM geography_columns
        WHERE type in ('Polygon', 'MultiPolygon')
        AND f_table_name = TG_TABLE_NAME LOOP
          -- will remove columns with geo data
          current_record := current_record::jsonb - geo_entities.f_geography_column;
      END LOOP;
    RETURN current_record;
    END;
    $$;


--
-- Name: update_change_time(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_change_time() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.change_time = floor(extract(epoch from clock_timestamp()) * 1000) + (CAST (nextval('change_time_seq') AS FLOAT)/1000);
      RETURN NEW;
    END;
    $$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: access_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_request (
    id text NOT NULL,
    user_id text,
    entity_id text,
    message text,
    project_id text,
    permission_group_id text,
    approved boolean,
    created_time timestamp with time zone DEFAULT now() NOT NULL,
    processed_by text,
    note text,
    processed_date timestamp with time zone
);


--
-- Name: ancestor_descendant_relation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ancestor_descendant_relation (
    id text NOT NULL,
    entity_hierarchy_id text NOT NULL,
    ancestor_id text NOT NULL,
    descendant_id text NOT NULL,
    generational_distance integer NOT NULL
);


--
-- Name: answer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.answer (
    id text NOT NULL,
    type text NOT NULL,
    survey_response_id text NOT NULL,
    question_id text NOT NULL,
    text text
);


--
-- Name: api_client; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_client (
    id text NOT NULL,
    username text NOT NULL,
    secret_key_hash text NOT NULL,
    user_account_id text
);


--
-- Name: api_request_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_request_log (
    id text NOT NULL,
    version double precision NOT NULL,
    endpoint text NOT NULL,
    user_id text,
    request_time timestamp without time zone DEFAULT now(),
    query jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    refresh_token text
);


--
-- Name: change_time_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.change_time_seq
    START WITH 100
    INCREMENT BY 1
    MINVALUE 100
    MAXVALUE 999
    CACHE 1
    CYCLE;


--
-- Name: clinic; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clinic (
    id text NOT NULL,
    name text NOT NULL,
    country_id text NOT NULL,
    geographical_area_id text NOT NULL,
    code text NOT NULL,
    type text,
    category_code character varying(3),
    type_name character varying(30)
);


--
-- Name: comment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comment (
    id text NOT NULL,
    user_id text,
    created_time timestamp with time zone DEFAULT now() NOT NULL,
    last_modified_time timestamp with time zone DEFAULT now() NOT NULL,
    text text NOT NULL
);


--
-- Name: country; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.country (
    id text NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


--
-- Name: dashboardGroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."dashboardGroup" (
    id integer NOT NULL,
    "organisationLevel" text NOT NULL,
    "userGroup" text NOT NULL,
    "organisationUnitCode" text NOT NULL,
    "dashboardReports" text[] DEFAULT '{}'::text[] NOT NULL,
    name text NOT NULL,
    code text,
    "projectCodes" text[] DEFAULT '{}'::text[]
);


--
-- Name: dashboardGroup_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."dashboardGroup_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dashboardGroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."dashboardGroup_id_seq" OWNED BY public."dashboardGroup".id;


--
-- Name: dashboardReport; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."dashboardReport" (
    id text NOT NULL,
    "drillDownLevel" integer,
    "dataBuilder" text,
    "dataBuilderConfig" jsonb,
    "viewJson" jsonb,
    "dataServices" jsonb DEFAULT '[{"isDataRegional": true}]'::jsonb
);


--
-- Name: data_element_data_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_element_data_group (
    id text NOT NULL,
    data_element_id text NOT NULL,
    data_group_id text NOT NULL
);


--
-- Name: data_source; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.data_source (
    id text NOT NULL,
    code text NOT NULL,
    type public.data_source_type NOT NULL,
    service_type public.service_type NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: dhis_sync_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dhis_sync_log (
    id text NOT NULL,
    record_id text NOT NULL,
    record_type text NOT NULL,
    imported double precision DEFAULT 0,
    updated double precision DEFAULT 0,
    deleted double precision DEFAULT 0,
    ignored double precision DEFAULT 0,
    error_list text,
    data text,
    dhis_reference text
);


--
-- Name: dhis_sync_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dhis_sync_queue (
    id text NOT NULL,
    type text NOT NULL,
    record_type text NOT NULL,
    record_id text NOT NULL,
    details text DEFAULT '{}'::text,
    change_time double precision DEFAULT (floor((date_part('epoch'::text, clock_timestamp()) * (1000)::double precision)) + ((nextval('public.change_time_seq'::regclass))::double precision / (100)::double precision)),
    priority integer DEFAULT 1,
    is_dead_letter boolean DEFAULT false,
    bad_request_count integer DEFAULT 0,
    is_deleted boolean DEFAULT false
);


--
-- Name: disaster; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.disaster (
    id text NOT NULL,
    type public.disaster_type NOT NULL,
    description text,
    name text NOT NULL,
    "countryCode" text NOT NULL
);


--
-- Name: disasterEvent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."disasterEvent" (
    id text NOT NULL,
    date timestamp with time zone NOT NULL,
    type public.disaster_event_type NOT NULL,
    "organisationUnitCode" text NOT NULL,
    "disasterId" text NOT NULL
);


--
-- Name: entity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity (
    id character varying(64) NOT NULL,
    code character varying(64) NOT NULL,
    parent_id character varying(64),
    name character varying(128) NOT NULL,
    type public.entity_type,
    point public.geography(Point,4326),
    region public.geography(MultiPolygon,4326),
    image_url text,
    country_code character varying(6),
    bounds public.geography(Polygon,4326),
    metadata jsonb,
    attributes jsonb DEFAULT '{}'::jsonb
);


--
-- Name: entity_hierarchy; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_hierarchy (
    id text NOT NULL,
    name text NOT NULL,
    canonical_types text[] DEFAULT '{}'::text[]
);


--
-- Name: entity_relation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_relation (
    id text NOT NULL,
    parent_id text NOT NULL,
    child_id text NOT NULL,
    entity_hierarchy_id text NOT NULL
);


--
-- Name: error_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.error_log (
    id text NOT NULL,
    message text,
    api_request_log_id text,
    type text,
    error_time timestamp without time zone DEFAULT now()
);


--
-- Name: feed_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feed_item (
    id text NOT NULL,
    country_id text,
    geographical_area_id text,
    user_id text,
    permission_group_id text,
    type text,
    record_id text,
    template_variables json,
    creation_date timestamp without time zone DEFAULT now()
);


--
-- Name: geographical_area; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.geographical_area (
    id text NOT NULL,
    name text NOT NULL,
    level_code text NOT NULL,
    level_name text NOT NULL,
    country_id text NOT NULL,
    parent_id text,
    code text
);


--
-- Name: indicator; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.indicator (
    id text NOT NULL,
    code text NOT NULL,
    builder text NOT NULL,
    config jsonb DEFAULT '{}'::jsonb NOT NULL
);


--
-- Name: mapOverlay; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."mapOverlay" (
    id text NOT NULL,
    name text NOT NULL,
    "userGroup" text NOT NULL,
    "dataElementCode" text NOT NULL,
    "isDataRegional" boolean DEFAULT true,
    "linkedMeasures" text[],
    "measureBuilderConfig" jsonb,
    "measureBuilder" character varying,
    "presentationOptions" jsonb DEFAULT '{}'::jsonb NOT NULL,
    "countryCodes" text[],
    "projectCodes" text[] DEFAULT '{}'::text[]
);


--
-- Name: mapOverlay_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."mapOverlay_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mapOverlay_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."mapOverlay_id_seq" OWNED BY public."mapOverlay".id;


--
-- Name: map_overlay_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_overlay_group (
    id text NOT NULL,
    name text NOT NULL,
    code text NOT NULL
);


--
-- Name: map_overlay_group_relation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_overlay_group_relation (
    id text NOT NULL,
    map_overlay_group_id text NOT NULL,
    child_id text NOT NULL,
    child_type text NOT NULL,
    sort_order integer
);


--
-- Name: meditrak_device; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meditrak_device (
    id text NOT NULL,
    user_id text NOT NULL,
    install_id text NOT NULL,
    platform character varying DEFAULT ''::character varying,
    app_version text,
    config jsonb DEFAULT '{}'::jsonb
);


--
-- Name: meditrak_sync_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meditrak_sync_queue (
    id text NOT NULL,
    type text NOT NULL,
    record_type text NOT NULL,
    record_id text NOT NULL,
    change_time double precision DEFAULT (floor((date_part('epoch'::text, clock_timestamp()) * (1000)::double precision)) + ((nextval('public.change_time_seq'::regclass))::double precision / (100)::double precision))
);


--
-- Name: migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    run_on timestamp without time zone NOT NULL
);


--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.migrations_id_seq
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
-- Name: ms1_sync_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ms1_sync_log (
    id text NOT NULL,
    record_type text NOT NULL,
    record_id text NOT NULL,
    count integer DEFAULT 1,
    error_list text,
    endpoint text,
    data text
);


--
-- Name: ms1_sync_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ms1_sync_queue (
    id text NOT NULL,
    type text NOT NULL,
    record_type text NOT NULL,
    record_id text NOT NULL,
    priority integer DEFAULT 1,
    details text,
    is_dead_letter boolean DEFAULT false,
    bad_request_count integer DEFAULT 0,
    change_time double precision DEFAULT (floor((date_part('epoch'::text, clock_timestamp()) * (1000)::double precision)) + ((nextval('public.change_time_seq'::regclass))::double precision / (100)::double precision)),
    is_deleted boolean DEFAULT false
);


--
-- Name: one_time_login; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.one_time_login (
    id text NOT NULL,
    user_id text NOT NULL,
    token text NOT NULL,
    creation_date timestamp with time zone DEFAULT now(),
    use_date timestamp with time zone
);


--
-- Name: option; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.option (
    id text NOT NULL,
    value text NOT NULL,
    label text,
    sort_order integer,
    option_set_id text NOT NULL,
    attributes jsonb DEFAULT '{}'::jsonb
);


--
-- Name: option_set; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.option_set (
    id text NOT NULL,
    name text NOT NULL
);


--
-- Name: permission_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permission_group (
    id text NOT NULL,
    name text NOT NULL,
    parent_id text
);


--
-- Name: project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.project (
    id text NOT NULL,
    code text NOT NULL,
    description text,
    sort_order integer,
    image_url text,
    default_measure text DEFAULT '126,171'::text,
    dashboard_group_name text DEFAULT 'General'::text,
    user_groups text[],
    logo_url text,
    entity_id text,
    entity_hierarchy_id text,
    config jsonb DEFAULT '{"permanentRegionLabels": true}'::jsonb
);


--
-- Name: psss_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.psss_session (
    id text NOT NULL,
    email text NOT NULL,
    access_policy jsonb NOT NULL,
    access_token text NOT NULL,
    access_token_expiry bigint NOT NULL,
    refresh_token text NOT NULL
);


--
-- Name: question; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.question (
    id text NOT NULL,
    text text NOT NULL,
    name text,
    type text NOT NULL,
    options text[],
    code text,
    detail text,
    option_set_id character varying,
    hook text,
    data_source_id text,
    CONSTRAINT data_source_id_not_null_on_conditions CHECK (((type = ANY (ARRAY['Instruction'::text, 'PrimaryEntity'::text, 'SubmissionDate'::text])) OR (data_source_id IS NOT NULL)))
);


--
-- Name: refresh_token; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_token (
    id text NOT NULL,
    user_id text NOT NULL,
    device text,
    token text NOT NULL,
    expiry double precision,
    meditrak_device_id text
);


--
-- Name: report; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report (
    id text NOT NULL,
    code text NOT NULL,
    config jsonb NOT NULL,
    permission_group_id text NOT NULL
);


--
-- Name: setting; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.setting (
    id text NOT NULL,
    key text NOT NULL,
    value text
);


--
-- Name: survey; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey (
    id text NOT NULL,
    name text NOT NULL,
    code text NOT NULL,
    permission_group_id text,
    country_ids text[] DEFAULT '{}'::text[],
    can_repeat boolean DEFAULT false,
    survey_group_id text,
    integration_metadata jsonb DEFAULT '{}'::jsonb,
    data_source_id text NOT NULL
);


--
-- Name: survey_group; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_group (
    id text NOT NULL,
    name text NOT NULL
);


--
-- Name: survey_response; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_response (
    id text NOT NULL,
    survey_id text NOT NULL,
    user_id text NOT NULL,
    assessor_name text NOT NULL,
    start_time timestamp with time zone NOT NULL,
    end_time timestamp with time zone NOT NULL,
    metadata text,
    submission_time timestamp with time zone,
    timezone text DEFAULT 'Pacific/Auckland'::text,
    entity_id text NOT NULL
);


--
-- Name: survey_response_comment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_response_comment (
    id text NOT NULL,
    survey_response_id text NOT NULL,
    comment_id text NOT NULL
);


--
-- Name: survey_screen; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_screen (
    id text NOT NULL,
    survey_id text NOT NULL,
    screen_number double precision NOT NULL
);


--
-- Name: survey_screen_component; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_screen_component (
    id text NOT NULL,
    question_id text NOT NULL,
    screen_id text NOT NULL,
    component_number double precision NOT NULL,
    answers_enabling_follow_up text[] DEFAULT '{}'::text[],
    is_follow_up boolean DEFAULT false,
    visibility_criteria character varying,
    validation_criteria character varying,
    question_label text,
    detail_label text,
    config character varying DEFAULT '{}'::character varying
);


--
-- Name: userSession; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."userSession" (
    id text NOT NULL,
    "userName" text NOT NULL,
    "accessToken" text,
    "refreshToken" text NOT NULL,
    "accessPolicy" jsonb
);


--
-- Name: user_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_account (
    id text NOT NULL,
    first_name text,
    last_name text,
    email text NOT NULL,
    gender text,
    creation_date timestamp with time zone DEFAULT now(),
    employer text,
    "position" text,
    mobile_number text,
    password_hash text NOT NULL,
    password_salt text NOT NULL,
    verified_email public.verified_email DEFAULT 'new_user'::public.verified_email,
    profile_image text
);


--
-- Name: user_entity_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_entity_permission (
    id text NOT NULL,
    user_id text,
    entity_id text,
    permission_group_id text
);


--
-- Name: user_reward; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_reward (
    id text NOT NULL,
    user_id text,
    coconuts bigint DEFAULT 0 NOT NULL,
    pigs bigint DEFAULT 0 NOT NULL,
    type character varying,
    record_id character varying,
    creation_date timestamp without time zone DEFAULT now()
);


--
-- Name: dashboardGroup id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."dashboardGroup" ALTER COLUMN id SET DEFAULT nextval('public."dashboardGroup_id_seq"'::regclass);


--
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Name: access_request access_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_request
    ADD CONSTRAINT access_request_pkey PRIMARY KEY (id);


--
-- Name: ancestor_descendant_relation ancestor_descendant_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ancestor_descendant_relation
    ADD CONSTRAINT ancestor_descendant_relation_pkey PRIMARY KEY (id);


--
-- Name: answer answer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer
    ADD CONSTRAINT answer_pkey PRIMARY KEY (id);


--
-- Name: answer answer_survey_response_id_question_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer
    ADD CONSTRAINT answer_survey_response_id_question_id_unique UNIQUE (survey_response_id, question_id);


--
-- Name: api_client api_client_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_client
    ADD CONSTRAINT api_client_pkey PRIMARY KEY (id);


--
-- Name: api_client api_client_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_client
    ADD CONSTRAINT api_client_username_key UNIQUE (username);


--
-- Name: api_request_log api_request_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_request_log
    ADD CONSTRAINT api_request_log_pkey PRIMARY KEY (id);


--
-- Name: clinic clinic_code; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinic
    ADD CONSTRAINT clinic_code UNIQUE (code);


--
-- Name: clinic clinic_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinic
    ADD CONSTRAINT clinic_pkey PRIMARY KEY (id);


--
-- Name: comment comment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (id);


--
-- Name: country country_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country
    ADD CONSTRAINT country_code_key UNIQUE (code);


--
-- Name: country country_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country
    ADD CONSTRAINT country_name_key UNIQUE (name);


--
-- Name: country country_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country
    ADD CONSTRAINT country_pkey PRIMARY KEY (id);


--
-- Name: dashboardGroup dashboardGroup_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."dashboardGroup"
    ADD CONSTRAINT "dashboardGroup_code_key" UNIQUE (code);


--
-- Name: dashboardGroup dashboardGroup_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."dashboardGroup"
    ADD CONSTRAINT "dashboardGroup_pkey" PRIMARY KEY (id);


--
-- Name: data_element_data_group data_element_data_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_element_data_group
    ADD CONSTRAINT data_element_data_group_pkey PRIMARY KEY (id);


--
-- Name: data_element_data_group data_element_data_group_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_element_data_group
    ADD CONSTRAINT data_element_data_group_unique UNIQUE (data_element_id, data_group_id);


--
-- Name: data_source data_source_code_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_source
    ADD CONSTRAINT data_source_code_type_key UNIQUE (code, type);


--
-- Name: data_source data_source_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_source
    ADD CONSTRAINT data_source_pkey PRIMARY KEY (id);


--
-- Name: dhis_sync_log dhis_sync_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dhis_sync_log
    ADD CONSTRAINT dhis_sync_log_pkey PRIMARY KEY (id);


--
-- Name: dhis_sync_log dhis_sync_log_record_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dhis_sync_log
    ADD CONSTRAINT dhis_sync_log_record_id_unique UNIQUE (record_id);


--
-- Name: dhis_sync_queue dhis_sync_queue_change_time_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dhis_sync_queue
    ADD CONSTRAINT dhis_sync_queue_change_time_key UNIQUE (change_time);


--
-- Name: dhis_sync_queue dhis_sync_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dhis_sync_queue
    ADD CONSTRAINT dhis_sync_queue_pkey PRIMARY KEY (id);


--
-- Name: dhis_sync_queue dhis_sync_queue_record_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dhis_sync_queue
    ADD CONSTRAINT dhis_sync_queue_record_id_unique UNIQUE (record_id);


--
-- Name: disasterEvent disasterEvent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."disasterEvent"
    ADD CONSTRAINT "disasterEvent_pkey" PRIMARY KEY (id);


--
-- Name: disaster disaster_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.disaster
    ADD CONSTRAINT disaster_pkey PRIMARY KEY (id);


--
-- Name: entity entity_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_code_key UNIQUE (code);


--
-- Name: entity_hierarchy entity_hierarchy_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_hierarchy
    ADD CONSTRAINT entity_hierarchy_name_key UNIQUE (name);


--
-- Name: entity_hierarchy entity_hierarchy_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_hierarchy
    ADD CONSTRAINT entity_hierarchy_pkey PRIMARY KEY (id);


--
-- Name: entity entity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_pkey PRIMARY KEY (id);


--
-- Name: entity_relation entity_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relation
    ADD CONSTRAINT entity_relation_pkey PRIMARY KEY (id);


--
-- Name: error_log error_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_log
    ADD CONSTRAINT error_log_pkey PRIMARY KEY (id);


--
-- Name: feed_item feed_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_item
    ADD CONSTRAINT feed_item_pkey PRIMARY KEY (id);


--
-- Name: geographical_area geographical_area_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.geographical_area
    ADD CONSTRAINT geographical_area_pkey PRIMARY KEY (id);


--
-- Name: indicator indicator_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator
    ADD CONSTRAINT indicator_code_key UNIQUE (code);


--
-- Name: indicator indicator_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.indicator
    ADD CONSTRAINT indicator_pkey PRIMARY KEY (id);


--
-- Name: meditrak_device install_id_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meditrak_device
    ADD CONSTRAINT install_id_pkey PRIMARY KEY (id);


--
-- Name: mapOverlay mapOverlay_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."mapOverlay"
    ADD CONSTRAINT "mapOverlay_id_key" UNIQUE (id);


--
-- Name: map_overlay_group map_overlay_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_overlay_group
    ADD CONSTRAINT map_overlay_group_pkey PRIMARY KEY (id);


--
-- Name: map_overlay_group_relation map_overlay_group_relation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_overlay_group_relation
    ADD CONSTRAINT map_overlay_group_relation_pkey PRIMARY KEY (id);


--
-- Name: meditrak_device meditrak_device_install_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meditrak_device
    ADD CONSTRAINT meditrak_device_install_id_unique UNIQUE (install_id);


--
-- Name: meditrak_sync_queue meditrak_sync_queue_change_time_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meditrak_sync_queue
    ADD CONSTRAINT meditrak_sync_queue_change_time_key UNIQUE (change_time);


--
-- Name: meditrak_sync_queue meditrak_sync_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meditrak_sync_queue
    ADD CONSTRAINT meditrak_sync_queue_pkey PRIMARY KEY (id);


--
-- Name: meditrak_sync_queue meditrak_sync_queue_record_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meditrak_sync_queue
    ADD CONSTRAINT meditrak_sync_queue_record_id_unique UNIQUE (record_id);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: ms1_sync_log ms1_sync_log_record_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ms1_sync_log
    ADD CONSTRAINT ms1_sync_log_record_id_unique UNIQUE (record_id);


--
-- Name: ms1_sync_queue ms1_sync_queue_record_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ms1_sync_queue
    ADD CONSTRAINT ms1_sync_queue_record_id_unique UNIQUE (record_id);


--
-- Name: one_time_login one_time_login_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_login
    ADD CONSTRAINT one_time_login_pkey PRIMARY KEY (id);


--
-- Name: one_time_login one_time_login_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_login
    ADD CONSTRAINT one_time_login_token_key UNIQUE (token);


--
-- Name: option option_option_set_id_value_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.option
    ADD CONSTRAINT option_option_set_id_value_unique UNIQUE (option_set_id, value);


--
-- Name: option option_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.option
    ADD CONSTRAINT option_pkey PRIMARY KEY (id);


--
-- Name: option_set option_set_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.option_set
    ADD CONSTRAINT option_set_name_key UNIQUE (name);


--
-- Name: option_set option_set_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.option_set
    ADD CONSTRAINT option_set_pkey PRIMARY KEY (id);


--
-- Name: permission_group permission_group_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_group
    ADD CONSTRAINT permission_group_name_key UNIQUE (name);


--
-- Name: permission_group permission_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_group
    ADD CONSTRAINT permission_group_pkey PRIMARY KEY (id);


--
-- Name: project project_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_code_key UNIQUE (code);


--
-- Name: project project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_pkey PRIMARY KEY (id);


--
-- Name: psss_session psss_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.psss_session
    ADD CONSTRAINT psss_session_pkey PRIMARY KEY (id);


--
-- Name: question question_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_code_unique UNIQUE (code);


--
-- Name: question question_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_pkey PRIMARY KEY (id);


--
-- Name: refresh_token refresh_token_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_pkey PRIMARY KEY (id);


--
-- Name: refresh_token refresh_token_user_id_device_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_user_id_device_unique UNIQUE (user_id, device);


--
-- Name: report report_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_code_key UNIQUE (code);


--
-- Name: report report_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_pkey PRIMARY KEY (id);


--
-- Name: setting setting_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.setting
    ADD CONSTRAINT setting_key_key UNIQUE (key);


--
-- Name: setting setting_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.setting
    ADD CONSTRAINT setting_pkey PRIMARY KEY (id);


--
-- Name: survey survey_code_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey
    ADD CONSTRAINT survey_code_unique UNIQUE (code);


--
-- Name: survey_group survey_group_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_group
    ADD CONSTRAINT survey_group_name_key UNIQUE (name);


--
-- Name: survey_group survey_group_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_group
    ADD CONSTRAINT survey_group_pkey PRIMARY KEY (id);


--
-- Name: survey survey_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey
    ADD CONSTRAINT survey_name_key UNIQUE (name);


--
-- Name: survey survey_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (id);


--
-- Name: survey_response_comment survey_response_comment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response_comment
    ADD CONSTRAINT survey_response_comment_pkey PRIMARY KEY (id);


--
-- Name: survey_response survey_response_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response
    ADD CONSTRAINT survey_response_pkey PRIMARY KEY (id);


--
-- Name: survey_screen_component survey_screen_component_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_screen_component
    ADD CONSTRAINT survey_screen_component_pkey PRIMARY KEY (id);


--
-- Name: survey_screen survey_screen_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_screen
    ADD CONSTRAINT survey_screen_pkey PRIMARY KEY (id);


--
-- Name: userSession userSession_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."userSession"
    ADD CONSTRAINT "userSession_id_key" UNIQUE (id);


--
-- Name: userSession userSession_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."userSession"
    ADD CONSTRAINT "userSession_pkey" PRIMARY KEY ("userName");


--
-- Name: user_account user_account_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_email_key UNIQUE (email);


--
-- Name: user_account user_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account
    ADD CONSTRAINT user_account_pkey PRIMARY KEY (id);


--
-- Name: user_entity_permission user_entity_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_entity_permission
    ADD CONSTRAINT user_entity_permission_pkey PRIMARY KEY (id);


--
-- Name: user_reward user_reward_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_reward
    ADD CONSTRAINT user_reward_pkey PRIMARY KEY (id);


--
-- Name: user_reward user_reward_type_record_id_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_reward
    ADD CONSTRAINT user_reward_type_record_id_unique UNIQUE (type, record_id);


--
-- Name: ancestor_descendant_relation_ancestor_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ancestor_descendant_relation_ancestor_id_idx ON public.ancestor_descendant_relation USING btree (ancestor_id);


--
-- Name: ancestor_descendant_relation_descendant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ancestor_descendant_relation_descendant_id_idx ON public.ancestor_descendant_relation USING btree (descendant_id);


--
-- Name: answer_question_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX answer_question_id_idx ON public.answer USING btree (question_id);


--
-- Name: answer_survey_response_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX answer_survey_response_id_idx ON public.answer USING btree (survey_response_id);


--
-- Name: answer_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX answer_type_idx ON public.answer USING btree (type);


--
-- Name: clinic_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clinic_country_id_idx ON public.clinic USING btree (country_id);


--
-- Name: clinic_geographical_area_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX clinic_geographical_area_id_idx ON public.clinic USING btree (geographical_area_id);


--
-- Name: dhis_sync_log_record_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dhis_sync_log_record_id_idx ON public.dhis_sync_log USING btree (record_id);


--
-- Name: dhis_sync_log_record_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dhis_sync_log_record_type_idx ON public.dhis_sync_log USING btree (record_type);


--
-- Name: dhis_sync_queue_change_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dhis_sync_queue_change_time_idx ON public.dhis_sync_queue USING btree (change_time);


--
-- Name: dhis_sync_queue_record_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dhis_sync_queue_record_id_idx ON public.dhis_sync_queue USING btree (record_id);


--
-- Name: dhis_sync_queue_record_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX dhis_sync_queue_record_type_idx ON public.dhis_sync_queue USING btree (record_type);


--
-- Name: entity_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_code ON public.entity USING btree (code);


--
-- Name: entity_parent_id_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX entity_parent_id_key ON public.entity USING btree (parent_id);


--
-- Name: geographical_area_country_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX geographical_area_country_id_idx ON public.geographical_area USING btree (country_id);


--
-- Name: geographical_area_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX geographical_area_parent_id_idx ON public.geographical_area USING btree (parent_id);


--
-- Name: idx_entity_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_entity_country_code ON public.entity USING btree (country_code);


--
-- Name: meditrak_sync_queue_change_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX meditrak_sync_queue_change_time_idx ON public.meditrak_sync_queue USING btree (change_time);


--
-- Name: meditrak_sync_queue_record_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX meditrak_sync_queue_record_id_idx ON public.meditrak_sync_queue USING btree (record_id);


--
-- Name: permission_group_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX permission_group_name_idx ON public.permission_group USING btree (name);


--
-- Name: permission_group_parent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX permission_group_parent_id_idx ON public.permission_group USING btree (parent_id);


--
-- Name: question_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX question_code_idx ON public.question USING btree (code);


--
-- Name: question_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX question_type_idx ON public.question USING btree (type);


--
-- Name: refresh_token_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX refresh_token_token_idx ON public.refresh_token USING btree (token);


--
-- Name: refresh_token_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX refresh_token_user_id_idx ON public.refresh_token USING btree (user_id);


--
-- Name: setting_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX setting_key_idx ON public.setting USING btree (key);


--
-- Name: survey_code_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_code_idx ON public.survey USING btree (code);


--
-- Name: survey_group_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_group_name_idx ON public.survey_group USING btree (name);


--
-- Name: survey_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_name_idx ON public.survey USING btree (name);


--
-- Name: survey_permission_group_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_permission_group_id_idx ON public.survey USING btree (permission_group_id);


--
-- Name: survey_response_end_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_response_end_time_idx ON public.survey_response USING btree (end_time);


--
-- Name: survey_response_start_time_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_response_start_time_idx ON public.survey_response USING btree (start_time);


--
-- Name: survey_response_survey_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_response_survey_id_idx ON public.survey_response USING btree (survey_id);


--
-- Name: survey_response_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_response_user_id_idx ON public.survey_response USING btree (user_id);


--
-- Name: survey_screen_component_component_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_screen_component_component_number_idx ON public.survey_screen_component USING btree (component_number);


--
-- Name: survey_screen_component_question_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_screen_component_question_id_idx ON public.survey_screen_component USING btree (question_id);


--
-- Name: survey_screen_component_screen_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_screen_component_screen_id_idx ON public.survey_screen_component USING btree (screen_id);


--
-- Name: survey_screen_screen_number_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_screen_screen_number_idx ON public.survey_screen USING btree (screen_number);


--
-- Name: survey_screen_survey_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_screen_survey_id_idx ON public.survey_screen USING btree (survey_id);


--
-- Name: survey_survey_group_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_survey_group_id_idx ON public.survey USING btree (survey_group_id);


--
-- Name: user_account_creation_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_account_creation_date_idx ON public.user_account USING btree (creation_date);


--
-- Name: user_account_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_account_email_idx ON public.user_account USING btree (email);


--
-- Name: user_account_first_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_account_first_name_idx ON public.user_account USING btree (first_name);


--
-- Name: user_account_last_name_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_account_last_name_idx ON public.user_account USING btree (last_name);


--
-- Name: user_entity_permission_entity_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_entity_permission_entity_id_idx ON public.user_entity_permission USING btree (entity_id);


--
-- Name: user_entity_permission_permission_group_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_entity_permission_permission_group_id_idx ON public.user_entity_permission USING btree (permission_group_id);


--
-- Name: user_entity_permission_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_entity_permission_user_id_idx ON public.user_entity_permission USING btree (user_id);


--
-- Name: access_request access_request_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER access_request_trigger AFTER INSERT OR DELETE OR UPDATE ON public.access_request FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: ancestor_descendant_relation ancestor_descendant_relation_immutable_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ancestor_descendant_relation_immutable_trigger AFTER UPDATE ON public.ancestor_descendant_relation FOR EACH ROW EXECUTE PROCEDURE public.immutable_table();


--
-- Name: answer answer_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER answer_trigger AFTER INSERT OR DELETE OR UPDATE ON public.answer FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: api_client api_client_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_client_trigger AFTER INSERT OR DELETE OR UPDATE ON public.api_client FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: clinic clinic_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER clinic_trigger AFTER INSERT OR DELETE OR UPDATE ON public.clinic FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: comment comment_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER comment_trigger AFTER INSERT OR DELETE OR UPDATE ON public.comment FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: country country_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER country_trigger AFTER INSERT OR DELETE OR UPDATE ON public.country FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: dashboardGroup dashboardgroup_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dashboardgroup_trigger AFTER INSERT OR DELETE OR UPDATE ON public."dashboardGroup" FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: data_element_data_group data_element_data_group_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER data_element_data_group_trigger AFTER INSERT OR DELETE OR UPDATE ON public.data_element_data_group FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: data_source data_source_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER data_source_trigger AFTER INSERT OR DELETE OR UPDATE ON public.data_source FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: dhis_sync_queue dhis_sync_queue_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER dhis_sync_queue_trigger BEFORE INSERT OR UPDATE ON public.dhis_sync_queue FOR EACH ROW EXECUTE PROCEDURE public.update_change_time();


--
-- Name: disaster disaster_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER disaster_trigger AFTER INSERT OR DELETE OR UPDATE ON public.disaster FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: disasterEvent disasterevent_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER disasterevent_trigger AFTER INSERT OR DELETE OR UPDATE ON public."disasterEvent" FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: entity_hierarchy entity_hierarchy_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_hierarchy_trigger AFTER INSERT OR DELETE OR UPDATE ON public.entity_hierarchy FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: entity_relation entity_relation_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_relation_trigger AFTER INSERT OR DELETE OR UPDATE ON public.entity_relation FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: entity entity_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER entity_trigger AFTER INSERT OR DELETE OR UPDATE ON public.entity FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: geographical_area geographical_area_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER geographical_area_trigger AFTER INSERT OR DELETE OR UPDATE ON public.geographical_area FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: indicator indicator_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER indicator_trigger AFTER INSERT OR DELETE OR UPDATE ON public.indicator FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: meditrak_device install_id_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER install_id_trigger AFTER INSERT OR DELETE OR UPDATE ON public.meditrak_device FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: map_overlay_group_relation map_overlay_group_relation_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER map_overlay_group_relation_trigger AFTER INSERT OR DELETE OR UPDATE ON public.map_overlay_group_relation FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: map_overlay_group map_overlay_group_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER map_overlay_group_trigger AFTER INSERT OR DELETE OR UPDATE ON public.map_overlay_group FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: mapOverlay mapoverlay_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mapoverlay_trigger AFTER INSERT OR DELETE OR UPDATE ON public."mapOverlay" FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: meditrak_device meditrak_device_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER meditrak_device_trigger AFTER INSERT OR DELETE OR UPDATE ON public.meditrak_device FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: meditrak_sync_queue meditrak_sync_queue_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER meditrak_sync_queue_trigger BEFORE INSERT OR UPDATE ON public.meditrak_sync_queue FOR EACH ROW EXECUTE PROCEDURE public.update_change_time();


--
-- Name: ms1_sync_log ms1_sync_log_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ms1_sync_log_trigger AFTER INSERT OR DELETE OR UPDATE ON public.ms1_sync_log FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: ms1_sync_queue ms1_sync_queue_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER ms1_sync_queue_trigger BEFORE INSERT OR UPDATE ON public.ms1_sync_queue FOR EACH ROW EXECUTE PROCEDURE public.update_change_time();


--
-- Name: one_time_login one_time_login_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER one_time_login_trigger AFTER INSERT OR DELETE OR UPDATE ON public.one_time_login FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: option_set option_set_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER option_set_trigger AFTER INSERT OR DELETE OR UPDATE ON public.option_set FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: option option_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER option_trigger AFTER INSERT OR DELETE OR UPDATE ON public.option FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: permission_group permission_group_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER permission_group_trigger AFTER INSERT OR DELETE OR UPDATE ON public.permission_group FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: project project_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER project_trigger AFTER INSERT OR DELETE OR UPDATE ON public.project FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: question question_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER question_trigger AFTER INSERT OR DELETE OR UPDATE ON public.question FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: refresh_token refresh_token_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER refresh_token_trigger AFTER INSERT OR DELETE OR UPDATE ON public.refresh_token FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: report report_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER report_trigger AFTER INSERT OR DELETE OR UPDATE ON public.report FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: setting setting_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER setting_trigger AFTER INSERT OR DELETE OR UPDATE ON public.setting FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: survey_group survey_group_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER survey_group_trigger AFTER INSERT OR DELETE OR UPDATE ON public.survey_group FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: survey_response_comment survey_response_comment_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER survey_response_comment_trigger AFTER INSERT OR DELETE OR UPDATE ON public.survey_response_comment FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: survey_response survey_response_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER survey_response_trigger AFTER INSERT OR DELETE OR UPDATE ON public.survey_response FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: survey_screen_component survey_screen_component_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER survey_screen_component_trigger AFTER INSERT OR DELETE OR UPDATE ON public.survey_screen_component FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: survey_screen survey_screen_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER survey_screen_trigger AFTER INSERT OR DELETE OR UPDATE ON public.survey_screen FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: survey survey_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER survey_trigger AFTER INSERT OR DELETE OR UPDATE ON public.survey FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: user_account user_account_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_account_trigger AFTER INSERT OR DELETE OR UPDATE ON public.user_account FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: user_entity_permission user_entity_permission_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_entity_permission_trigger AFTER INSERT OR DELETE OR UPDATE ON public.user_entity_permission FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: user_reward user_reward_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_reward_trigger AFTER INSERT OR DELETE OR UPDATE ON public.user_reward FOR EACH ROW EXECUTE PROCEDURE public.notification();


--
-- Name: access_request access_request_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_request
    ADD CONSTRAINT access_request_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES public.entity(id);


--
-- Name: access_request access_request_permission_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_request
    ADD CONSTRAINT access_request_permission_group_id_fkey FOREIGN KEY (permission_group_id) REFERENCES public.permission_group(id);


--
-- Name: access_request access_request_processed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_request
    ADD CONSTRAINT access_request_processed_by_fkey FOREIGN KEY (processed_by) REFERENCES public.user_account(id);


--
-- Name: access_request access_request_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_request
    ADD CONSTRAINT access_request_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.project(id);


--
-- Name: access_request access_request_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_request
    ADD CONSTRAINT access_request_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id);


--
-- Name: ancestor_descendant_relation ancestor_descendant_relation_ancestor_id_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ancestor_descendant_relation
    ADD CONSTRAINT ancestor_descendant_relation_ancestor_id_entity_id_fk FOREIGN KEY (ancestor_id) REFERENCES public.entity(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ancestor_descendant_relation ancestor_descendant_relation_descendant_id_entity_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ancestor_descendant_relation
    ADD CONSTRAINT ancestor_descendant_relation_descendant_id_entity_id_fk FOREIGN KEY (descendant_id) REFERENCES public.entity(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: ancestor_descendant_relation ancestor_descendant_relation_entity_hierarchy_id_entity_hierarc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ancestor_descendant_relation
    ADD CONSTRAINT ancestor_descendant_relation_entity_hierarchy_id_entity_hierarc FOREIGN KEY (entity_hierarchy_id) REFERENCES public.entity_hierarchy(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: answer answer_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer
    ADD CONSTRAINT answer_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.question(id);


--
-- Name: answer answer_survey_response_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.answer
    ADD CONSTRAINT answer_survey_response_id_fkey FOREIGN KEY (survey_response_id) REFERENCES public.survey_response(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: api_client api_client_user_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_client
    ADD CONSTRAINT api_client_user_account_id_fkey FOREIGN KEY (user_account_id) REFERENCES public.user_account(id);


--
-- Name: api_request_log api_request_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_request_log
    ADD CONSTRAINT api_request_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: clinic clinic_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinic
    ADD CONSTRAINT clinic_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: clinic clinic_geographical_area_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clinic
    ADD CONSTRAINT clinic_geographical_area_id_fkey FOREIGN KEY (geographical_area_id) REFERENCES public.geographical_area(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: comment comment_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id);


--
-- Name: data_element_data_group data_element_data_group_data_element_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_element_data_group
    ADD CONSTRAINT data_element_data_group_data_element_id_fk FOREIGN KEY (data_element_id) REFERENCES public.data_source(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: data_element_data_group data_element_data_group_data_group_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.data_element_data_group
    ADD CONSTRAINT data_element_data_group_data_group_id_fk FOREIGN KEY (data_group_id) REFERENCES public.data_source(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: disasterEvent disaster_event_disaster_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."disasterEvent"
    ADD CONSTRAINT disaster_event_disaster_id_fk FOREIGN KEY ("disasterId") REFERENCES public.disaster(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: entity entity_parent_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity
    ADD CONSTRAINT entity_parent_fk FOREIGN KEY (parent_id) REFERENCES public.entity(id);


--
-- Name: entity_relation entity_relation_child_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relation
    ADD CONSTRAINT entity_relation_child_id_fkey FOREIGN KEY (child_id) REFERENCES public.entity(id);


--
-- Name: entity_relation entity_relation_entity_hierarchy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relation
    ADD CONSTRAINT entity_relation_entity_hierarchy_id_fkey FOREIGN KEY (entity_hierarchy_id) REFERENCES public.entity_hierarchy(id);


--
-- Name: entity_relation entity_relation_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_relation
    ADD CONSTRAINT entity_relation_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.entity(id);


--
-- Name: error_log error_log_api_request_log_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_log
    ADD CONSTRAINT error_log_api_request_log_id_fkey FOREIGN KEY (api_request_log_id) REFERENCES public.api_request_log(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: feed_item feed_item_country_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_item
    ADD CONSTRAINT feed_item_country_fk FOREIGN KEY (country_id) REFERENCES public.country(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: feed_item feed_item_geographical_area_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_item
    ADD CONSTRAINT feed_item_geographical_area_fk FOREIGN KEY (geographical_area_id) REFERENCES public.geographical_area(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: feed_item feed_item_permission_group_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_item
    ADD CONSTRAINT feed_item_permission_group_fk FOREIGN KEY (permission_group_id) REFERENCES public.permission_group(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: feed_item feed_item_user_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feed_item
    ADD CONSTRAINT feed_item_user_fk FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: geographical_area geographical_area_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.geographical_area
    ADD CONSTRAINT geographical_area_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: geographical_area geographical_area_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.geographical_area
    ADD CONSTRAINT geographical_area_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.geographical_area(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: meditrak_device install_id_user_account_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meditrak_device
    ADD CONSTRAINT install_id_user_account_id_fk FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: map_overlay_group_relation map_overlay_group_relation_map_overlay_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_overlay_group_relation
    ADD CONSTRAINT map_overlay_group_relation_map_overlay_group_id_fkey FOREIGN KEY (map_overlay_group_id) REFERENCES public.map_overlay_group(id);


--
-- Name: one_time_login one_time_logins_user_id_users_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_login
    ADD CONSTRAINT one_time_logins_user_id_users_id_fk FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: option option_option_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.option
    ADD CONSTRAINT option_option_set_id_fk FOREIGN KEY (option_set_id) REFERENCES public.option_set(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: permission_group permission_group_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permission_group
    ADD CONSTRAINT permission_group_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.permission_group(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: project project_entity_hierarchy_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.project
    ADD CONSTRAINT project_entity_hierarchy_id_fkey FOREIGN KEY (entity_hierarchy_id) REFERENCES public.entity_hierarchy(id);


--
-- Name: question question_data_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_data_source_id_fkey FOREIGN KEY (data_source_id) REFERENCES public.data_source(id);


--
-- Name: question question_option_set_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_option_set_id_fk FOREIGN KEY (option_set_id) REFERENCES public.option_set(id) ON UPDATE RESTRICT ON DELETE RESTRICT;


--
-- Name: refresh_token refresh_token_meditrak_device_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_meditrak_device_id_fk FOREIGN KEY (meditrak_device_id) REFERENCES public.meditrak_device(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: refresh_token refresh_token_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_token
    ADD CONSTRAINT refresh_token_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: report report_permission_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_permission_group_id_fkey FOREIGN KEY (permission_group_id) REFERENCES public.permission_group(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: survey survey_data_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey
    ADD CONSTRAINT survey_data_source_id_fkey FOREIGN KEY (data_source_id) REFERENCES public.data_source(id);


--
-- Name: survey survey_permission_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey
    ADD CONSTRAINT survey_permission_group_id_fkey FOREIGN KEY (permission_group_id) REFERENCES public.permission_group(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: survey_response_comment survey_response_comment_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response_comment
    ADD CONSTRAINT survey_response_comment_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comment(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: survey_response_comment survey_response_comment_survey_response_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response_comment
    ADD CONSTRAINT survey_response_comment_survey_response_id_fkey FOREIGN KEY (survey_response_id) REFERENCES public.survey_response(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: survey_response survey_response_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response
    ADD CONSTRAINT survey_response_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES public.entity(id) ON UPDATE CASCADE;


--
-- Name: survey_response survey_response_survey_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response
    ADD CONSTRAINT survey_response_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES public.survey(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: survey_response survey_response_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_response
    ADD CONSTRAINT survey_response_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: survey_screen_component survey_screen_component_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_screen_component
    ADD CONSTRAINT survey_screen_component_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.question(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: survey_screen_component survey_screen_component_screen_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_screen_component
    ADD CONSTRAINT survey_screen_component_screen_id_fkey FOREIGN KEY (screen_id) REFERENCES public.survey_screen(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: survey_screen survey_screen_survey_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_screen
    ADD CONSTRAINT survey_screen_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES public.survey(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: survey survey_survey_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey
    ADD CONSTRAINT survey_survey_group_id_fkey FOREIGN KEY (survey_group_id) REFERENCES public.survey_group(id) ON UPDATE CASCADE ON DELETE SET NULL;


--
-- Name: user_entity_permission user_entity_permission_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_entity_permission
    ADD CONSTRAINT user_entity_permission_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES public.entity(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_entity_permission user_entity_permission_permission_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_entity_permission
    ADD CONSTRAINT user_entity_permission_permission_group_id_fkey FOREIGN KEY (permission_group_id) REFERENCES public.permission_group(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_entity_permission user_entity_permission_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_entity_permission
    ADD CONSTRAINT user_entity_permission_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: user_reward user_reward_user_id_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_reward
    ADD CONSTRAINT user_reward_user_id_fk FOREIGN KEY (user_id) REFERENCES public.user_account(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: schema_change_trigger; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER schema_change_trigger ON ddl_command_end
   EXECUTE PROCEDURE public.schema_change_notification();


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO tupaia;


--
-- PostgreSQL database dump complete
--

--
-- PostgreSQL database dump
--

-- Dumped from database version 11.3
-- Dumped by pg_dump version 11.3

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

ALTER TABLE ONLY public.migrations DROP CONSTRAINT migrations_pkey;
ALTER TABLE public.migrations ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE public.migrations_id_seq;
DROP TABLE public.migrations;
SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.migrations (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    run_on timestamp without time zone NOT NULL
);


--
-- Name: migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.migrations_id_seq
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
-- Name: migrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations ALTER COLUMN id SET DEFAULT nextval('public.migrations_id_seq'::regclass);


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.migrations (id, name, run_on) FROM stdin;
1	/20180411032938-createAnswerTable	2018-06-01 01:40:39.749
2	/20180411032947-createApiRequestLogTable	2018-06-01 01:40:39.762
3	/20180411033003-createClinicTable	2018-06-01 01:40:39.775
4	/20180411033011-createCountryTable	2018-06-01 01:40:39.787
5	/20180411034141-createDhisSyncQueueTable	2018-06-01 01:40:39.798
6	/20180411034202-createDhisSyncLogTable	2018-06-01 01:40:39.819
7	/20180411034213-createErrorLogTable	2018-06-01 01:40:39.829
8	/20180411034222-createGeographicalAreaTable	2018-06-01 01:40:39.842
9	/20180411034237-createMeditrakSyncQueueTable	2018-06-01 01:40:39.862
10	/20180411034254-createPermissionGroupTable	2018-06-01 01:40:39.877
11	/20180411034302-createQuestionTable	2018-06-01 01:40:39.895
12	/20180411034309-createRefreshTokenTable	2018-06-01 01:40:39.904
13	/20180411034315-createSettingTable	2018-06-01 01:40:39.912
14	/20180411034322-createSurveyTable	2018-06-01 01:40:39.922
15	/20180411034328-createSurveyGroupTable	2018-06-01 01:40:39.934
16	/20180411034336-createSurveyResponseTable	2018-06-01 01:40:39.944
17	/20180411034344-createSurveyScreenTable	2018-06-01 01:40:39.955
18	/20180411034351-createSurveyScreenComponentTable	2018-06-01 01:40:39.968
19	/20180411034420-createUserAccountTable	2018-06-01 01:40:39.986
20	/20180411034429-createUserCountryPermissionTable	2018-06-01 01:40:39.997
21	/20180411045051-addTableRelationships	2018-06-01 01:40:40.009
22	/20180411091413-CreateUserRewardTable	2018-06-01 01:40:40.044
23	/20180426071045-addOrganisationUnitCodesToGeographicalAreas	2018-06-01 01:40:40.053
24	/20180426073304-createUserGeographicalAreaPermissionTable	2018-06-01 01:40:40.072
25	/20180503062832-FeedItem	2018-06-01 01:40:40.096
26	/20180503065148-AddTimestampToFeedItem	2018-06-01 01:40:40.113
27	/20180504110400-ChangeFeedItemCacheToTemplateVariables	2018-06-01 01:40:40.122
28	/20180509045837-AddLinkToFeedItems	2018-06-01 01:40:40.136
29	/20180510015244-AddAnnouncementFeedItem	2018-06-01 01:40:40.15
30	/20180510021012-RemoveLinkColumnFromFeed	2018-06-01 01:40:40.16
31	/20180511003957-AddModelRelationshipsToUserRewards	2018-06-01 01:40:40.17
32	/20180511004328-AddCreatedToRewards	2018-06-01 01:40:40.185
33	/20180511011825-RemoveUniqueConstraintFromUserReward	2018-06-01 01:40:40.193
34	/20180511014239-PopulateUserRewards	2018-06-01 01:40:40.338
35	/20180515004232-ChangeFeedCreatedToCreationDate	2018-06-01 01:40:40.345
36	/20180516035341-ChangeModelNameToFeedItemType	2018-06-01 01:40:40.363
37	/20180516035629-ChangeRewardModelNameToType	2018-06-01 01:40:40.372
38	/20180517050445-RenameModelIdToRecordId	2018-06-01 01:40:40.378
39	/20180531102754-CreateInstallIdTable	2018-06-01 01:40:40.394
40	/20180531235913-AddPlatformToInstallId	2018-06-01 01:40:40.408
41	/20180603211142-RemoveRepeatingSurveyCoconuts	2018-06-03 21:53:32.29
42	/20180604032437-fix-json-in-feed-items	2018-06-04 04:14:25.474
43	/20180604034558-fix-ids-for-announcement-items	2018-06-04 04:14:25.663
44	/20180611202247-DeleteOrphanGeographicalAreas	2018-06-12 03:49:06.106
45	/20180605215529-AddVisibilityCriteriaToSurveyScreenComponent	2018-07-27 02:47:47.783
46	/20180605222815-ChangeDefaultForAnswersEnablingFollowUp	2018-07-27 02:47:47.797
47	/20180605234358-ChangeDefaultForSurveyCountries	2018-07-27 02:47:47.806
48	/20180606025742-AddValidationCriteriaToSurveyScreenComponent	2018-07-27 02:47:47.813
49	/20180606040539-AnswersEnablingFollowUpToVisibilityCriteria	2018-07-27 02:47:48.124
50	/20180611202249-CreateUserClinicPermission	2018-07-27 02:47:48.347
52	/20180611202251-ImportOrganisationUnitCodesFromDhis	2018-07-27 02:47:54.861
53	/20180709061124-AddFacilityChangeRecords	2018-07-27 02:47:55.061
54	/20180710000210-AddAreaChangeRecords	2018-07-27 02:47:55.076
55	/20180717003225-RemoveRedundantUserCountryPermissionChangeRecord	2018-07-27 02:47:55.347
56	/20180611202250-AddCountryCodesToFacilityCodes	2018-07-27 03:11:05.755
57	/20180723054145-RedateSocialHealthFeedAnnouncement	2018-07-30 01:58:40.47
58	/20180716044506-CreateOneTimeLoginTable	2018-08-13 04:59:22.157
59	/20180822001459-AddSubmissionTime	2018-08-22 03:59:02.459
60	/20180827095252-AddServerNameColumns	2018-08-29 09:51:33.497
61	/20180831010353-ConvertAggregationServerNameToIsDataRegional	2018-09-03 09:28:51.965
62	/20180903221412-AddPriorityToDhisSyncQueue	2018-09-03 22:24:05.145
63	/20180919063336-AddTimezoneToSurveyResponse	2018-09-19 07:08:40.266
64	/20181113232232-createOptionSetTables	2018-12-05 05:23:07.755
65	/20181204021653-makeOptionSetNameUnique	2018-12-05 05:23:07.78
66	/20181210033201-DeleteUserCountryPermissionSyncRecords	2019-01-14 05:13:01.281
67	/20181211010309-AddMissingSubmissionTimes	2019-01-14 05:13:01.398
68	/20190205071030-AlterTriggerToHappenOnInsert	2019-02-05 07:26:28.092
69	/20190207032726-ChangeOldBCD1Responses	2019-02-07 04:18:17.456
70	/20180806045523-CreateUserSessionTable	2019-02-20 02:02:39.23
71	/20180806045535-CreateMapOverlayTable	2019-02-20 02:02:39.245
72	/20180806045544-CreateDashboardReportTable	2019-02-20 02:02:39.253
73	/20180806045553-CreateDashboardTabTable	2019-02-20 02:02:39.262
74	/20180806045709-PopulateDashboardReports	2019-02-20 02:02:39.284
75	/20180806045715-PopulateDashboardTabs	2019-02-20 02:02:39.296
76	/20180806045722-PopulateMapOverlays	2019-02-20 02:02:39.367
77	/20180828015804-AddCountrySpecificFlagToReportsAndOverlays	2019-02-20 02:02:39.389
78	/20180830061452-AddAccessPolicyToUserSession	2019-02-20 02:02:39.411
79	/20180830092310-AddCodeToDashboardTab	2019-02-20 02:02:39.418
80	/20180830092315-BuildReproductiveHealthDashboards	2019-02-20 02:02:39.424
81	/20180903025444-BuildFamilyPlanningValidationDashboard	2019-02-20 02:02:39.428
82	/20180903213305-SwitchColumnsAndRowsFamilyPlanning	2019-02-20 02:02:39.432
83	/20180905083227-BuildFamilyPlanningValidationReports	2019-02-20 02:02:39.438
84	/20180905090955-MoveDataElementColumnTitleForFP	2019-02-20 02:02:39.442
85	/20180905095249-BuildMCH05And03ValidationReports	2019-02-20 02:02:39.447
86	/20180905102415-SwitchColumnsAndRowsHomeVisits	2019-02-20 02:02:39.451
87	/20180910004520-StripFromRowNamesFamilyPlanning	2019-02-20 02:02:39.455
88	/20180910013150-AddTotalsToFamilyPlanning	2019-02-20 02:02:39.459
89	/20180910015304-OrderRowsFamilyPlanning	2019-02-20 02:02:39.465
90	/20180910044327-AllowMultipleCategoriesInTable	2019-02-20 02:02:39.469
91	/20180910051853-StripServiceRowNamesUsingRegex	2019-02-20 02:02:39.473
92	/20180910053016-AddClinicToVisitsValidation	2019-02-20 02:02:39.476
93	/20180910055439-HomeClinicVisitsShouldShowTotals	2019-02-20 02:02:39.479
94	/20180910063802-BuildDeliveriesValidationReport	2019-02-20 02:02:39.484
95	/20180912065036-AddTotalLineToMCH07	2019-02-20 02:02:39.487
96	/20180912065445-ReorderImms	2019-02-20 02:02:39.491
97	/20180912065745-DeleteMCH4FromMCH01	2019-02-20 02:02:39.496
98	/20180912224455-CustomiseDateColumnNameDeliveries	2019-02-20 02:02:39.499
99	/20180913063315-MovePeriodGranularityToViewJson	2019-02-20 02:02:39.503
100	/20180913225207-SwitchColumnsAndRowsMCH05	2019-02-20 02:02:39.551
101	/20180913230745-AddTotalsColumnToMCH05	2019-02-20 02:02:39.555
102	/20180913235047-SplitTotalsMCH05	2019-02-20 02:02:39.558
103	/20180914001813-RemoveColumnTitles	2019-02-20 02:02:39.561
104	/20180914005215-AddTotalsColumnToMCH0304	2019-02-20 02:02:39.565
105	/20180914005332-ReRenameMCH0304	2019-02-20 02:02:39.568
106	/20180917001145-BuildTotalHighRiskPregnanciesValidationReport	2019-02-20 02:02:39.572
107	/20180917001148-BuildECPValidationReport	2019-02-20 02:02:39.576
108	/20180917002810-ReorderValidationReports	2019-02-20 02:02:39.579
109	/20180917002812-RenameMCH01	2019-02-20 02:02:39.583
110	/20180917065000-RenameRHValidationDashboardGroup	2019-02-20 02:02:39.587
111	/20180917065554-BuildHighPriorityFP	2019-02-20 02:02:39.592
112	/20180918045054-MoveUseValueIfNameMatches	2019-02-20 02:02:39.595
113	/20180918045408-ChangeQueryJsonToDataBuilderConfig	2019-02-20 02:02:39.599
114	/20180918045705-RemoveApiRouteFromDataBuilderConfig	2019-02-20 02:02:39.602
115	/20180920060226-AddStackIdToBarCharts	2019-02-20 02:02:39.606
116	/20180920230539-MoveViewJsonStuffToDataBuilderConfig	2019-02-20 02:02:39.61
117	/20180920232717-BuildHighPriorityMCH	2019-02-20 02:02:39.616
118	/20180924050102-AddPeriodGranularityToMedsByFacility	2019-02-20 02:02:39.619
119	/20180925011124-RemoveIncorrectAggregationTypes	2019-02-20 02:02:39.623
120	/20180925060833-RemoveIndicators	2019-02-20 02:02:39.626
121	/20180925065555-AddLabelsToMultiDataElement	2019-02-20 02:02:39.631
122	/20180926051407-RenamePriorityDiseaseOverlay	2019-02-20 02:02:39.64
123	/20181001004147-ClarifyDescriptionMedsAvailability	2019-02-20 02:02:39.643
124	/20181001055147-BuildIMMS0102	2019-02-20 02:02:39.648
125	/20181001064741-BuildIMMS0103	2019-02-20 02:02:39.652
126	/20181001072924-BuildIMMSIndicators	2019-02-20 02:02:39.658
127	/20181019033903-RHTabsOnlyInTonga	2019-02-20 02:02:39.661
128	/20181102060638-TurnOffDisasterResponseInTonga	2019-02-20 02:02:39.664
129	/20181115041947-RHDashboardsOnInDemoLand	2019-02-20 02:02:39.669
130	/20181119052246-RemoveReferenceTo-TEXTDataElements	2019-02-20 02:02:39.673
131	/20181119054850-RemoveDuplicateElectricitySourceOverlay	2019-02-20 02:02:39.676
132	/20181128235419-SetBarChartRange	2019-02-20 02:02:39.68
133	/20181129003443-ANZGITAInventory	2019-02-20 02:02:39.685
134	/20181130025656-ANZGITASetRegionalFlag	2019-02-20 02:02:39.688
135	/20181130032020-ANZGITAAddSwanHill	2019-02-20 02:02:39.691
136	/20181130035414-ANZGITAUpdateVaricealBander	2019-02-20 02:02:39.698
137	/20181203232213-AddRawDataDownloadsDashboardTab	2019-02-20 02:02:39.702
138	/20181204021405-ANZGITA-excel	2019-02-20 02:02:39.706
139	/20181205051312-ReverseDisasterResponseCheckboxes	2019-02-20 02:02:39.709
140	/20181211040528-AddGreenRedColorsToDisasterResponse	2019-02-20 02:02:39.712
141	/20181211221442-StartCountryLevelDisasterResponseDashboard	2019-02-20 02:02:39.717
142	/20181217053723-ChangeWaterPurifyingTabletsType	2019-02-20 02:02:39.72
143	/20181217233048-FixMeasures	2019-02-20 02:02:39.725
144	/20181219000000-UpdateMeasureDisplayTypes	2019-02-20 02:02:39.729
145	/20181219040127-UpdateMapMeasureTable	2019-02-20 02:02:39.741
146	/20181221011216-UpdateCriticalMedicinesChartTitle	2019-02-20 02:02:39.745
147	/20190110231222-AddMeasureSort	2019-02-20 02:02:39.849
148	/20190111003836-UpdateWaterPurification	2019-02-20 02:02:39.855
149	/20190115011504-RenameTotalHighRiskPregnancies	2019-02-20 02:02:39.861
150	/20190115234004-SetWaterPurificationToRadius	2019-02-20 02:02:39.864
151	/20190116024849-UpdateRadiusIcons	2019-02-20 02:02:39.868
152	/20190117022340-RemoveVaccinationAtFacilityFromDashboard	2019-02-20 02:02:39.871
153	/20190123054504-addDataConfMapOverlay	2019-02-20 02:02:39.874
154	/20190206033736-IHRMapOverlays	2019-02-20 02:02:39.879
155	/20190206235343-IHRMatrixReport	2019-02-20 02:02:39.883
156	/20190208044642-ConstrainImmsReportsToSingleYear	2019-02-20 02:02:39.887
157	/20190212063050-FixServiceSuggestionDrillDown	2019-02-20 02:02:39.89
158	/20190213041645-IHRBarChart	2019-02-20 02:02:39.893
159	/20190214005038-AddExtraFormattingInfoColumn	2019-02-20 02:02:39.902
160	/20190217222420-IHREditMapOverlayNames	2019-02-20 02:02:39.905
161	/20190219000624-TurnOnDisasterResponseVanuatu	2019-02-20 02:02:39.908
162	/20190219034138-UpdateIHROverlayPermissions	2019-02-20 02:02:39.911
163	/20190217233150-MakeMapOverlaysCountrySpecific	2019-02-20 02:07:06.602
164	/20190218001403-IsolatePEHSAndIHRToCountries	2019-02-20 02:07:06.614
165	/20190222000001-AddEntityTable	2019-02-20 23:26:45.16
166	/20190222000002-AddFacilityTypeColumns	2019-02-20 23:26:45.555
167	/20190222000003-AddFacilityEntities	2019-02-20 23:26:46.578
168	/20190222000004-AddRegionEntities	2019-02-20 23:26:49.975
169	/20190220021712-AddAdditionalEntityFields	2019-02-22 04:19:07.696
170	/20190221233026-AddEntityBounds	2019-02-25 03:27:30.695
171	/20190222033833-AddVenezuela	2019-02-25 03:27:31.788
172	/20190222072224-AddPointBounds	2019-02-25 03:27:31.828
173	/20190224230636-FixVenezuelaEntityCodes	2019-02-25 03:27:31.84
174	/20190225021100-AddTypeDetailsToVenezuela	2019-02-25 03:27:31.866
175	/20190224231803-FixVenezuelaEntityCodes	2019-02-25 03:35:12.156
176	/20190226235914-FixVenezuelaHierarchy	2019-02-27 05:27:19.394
177	/20190304232043-CreateTongaCommunityHealthFacilityDashboard	2019-03-06 06:14:51.026
178	/20190305020301-CreateTongaCommunityHealthReports	2019-03-06 06:14:51.134
179	/20190305062226-CreateDemoCommunityHealthDashboard	2019-03-06 06:14:51.174
180	/20190314025109-AddQuestionLabelToComponents	2019-03-15 04:40:01.586
181	/20190315033609-AddVenezuelaRawDataDownloads	2019-03-15 05:38:41.644
182	/20190106231028-BuildBasicDisasterResponseMetrics	2019-03-21 04:21:59.47
183	/20190109000522-CreateDisasterEnums	2019-03-21 04:21:59.62
184	/20190109005419-CreateDisasterTable	2019-03-21 04:21:59.661
185	/20190109005425-CreateDisasterEventTable	2019-03-21 04:21:59.706
186	/20190125023420-CreateDashboardModeEnum	2019-03-21 04:21:59.718
187	/20190125023839-AddDashboardGroupModeColumn	2019-03-21 04:21:59.746
188	/20190129013217-CreateDisasterDashboardReport	2019-03-21 04:21:59.865
189	/20190208060028-AddDisasterOverlays	2019-03-21 04:21:59.902
190	/20190226025209-AddDisasterStatusToOverlay	2019-03-21 04:21:59.968
191	/20190226043641-AddFacilityTypeDisasterOverlay	2019-03-21 04:22:00.035
192	/20190226062002-AddDefaultIndicatorToMeasures	2019-03-21 04:22:00.056
193	/20190227042102-CreateDisasterAffectedFacilitiesDashboard	2019-03-21 04:22:00.071
194	/20190301032043-UpdateFacilitiesAffectedByDisasterMeasure	2019-03-21 04:22:00.083
195	/20190302025555-SetDisasterResponseDashboardViewmode	2019-03-21 04:22:00.098
196	/20190302025855-AddDisasterResponseDashboardsToDemoLand	2019-03-21 04:22:00.116
197	/20190303233005-RenameFacilitiesAffectedReport	2019-03-21 04:22:00.127
198	/20190304000300-AddNormalInpatientBedsOverlay	2019-03-21 04:22:00.163
199	/20190307014158-AddFacilityStatusPostDisasterReport	2019-03-21 04:22:00.187
200	/20190308065702-UpdateDisasterAffectedFacilitiesByTypeReport	2019-03-21 04:22:00.196
201	/20190312035718-UpdateDisasterResponseBasicFacilityMetrics	2019-03-21 04:22:00.219
202	/20190312051810-BuildDisasterResponseInfrastructureImpactReport	2019-03-21 04:22:00.248
203	/20190314054424-DisasterOverlayTweaks	2019-03-21 04:22:00.293
204	/20190314231152-RefactorBasicDisasterDataComparisonReport	2019-03-21 04:22:00.302
205	/20190315024428-AddBoundsandPointsForBrokenDemoLandFacilities	2019-03-21 04:22:00.333
206	/20190315034646-BuildSingleValueDisasterFacilityMetrics	2019-03-21 04:22:00.344
207	/20190318223802-AddTitleToInfrastructureImpact	2019-03-21 04:22:00.356
208	/20190318230928-UseNewInpatientBedsInDisasterResponseComparisons	2019-03-21 04:22:00.363
209	/20190320053827-UpdateDisasterResponseComparisonCodes	2019-03-21 04:22:00.371
210	/20190320223745-ConvertAffectedStatusToPrimaryMeasure	2019-03-21 04:22:00.409
211	/20190321005029-UseNewDataBuilderForImpactedInfrastructure	2019-03-21 04:22:00.418
212	/20190321031718-FixIconLegendForDisasterAffectedFacilities	2019-03-21 04:22:00.455
213	/20190321035735-FlipElectricityAndWaterDamage	2019-03-21 04:22:00.463
214	/20190328033334-RemoveNoFridgePresentMeasure	2019-03-28 06:22:26.313
215	/20190403233329-AddCHClinicDressings	2019-04-04 00:45:19.727
216	/20190404003347-AddCHClinicDressingToDistrictAndFacility	2019-04-04 00:45:19.763
217	/20190403085602-UpdateDisasterResponseSurveysAndReports	2019-04-11 00:19:55.09
218	/20190405001207-UpdateLatestDataValueDateReports	2019-04-11 00:19:55.107
219	/20190405003121-DeleteVUDisasterDashboardGroups	2019-04-11 00:19:55.12
220	/20190405015626-UpdateDisasterPieChartColor	2019-04-11 00:19:55.13
221	/20190408232032-UpdateRawDataDownloadDisasterSurveys	2019-04-11 00:19:55.153
222	/20190410062856-AddTongaCommunityHealthComplicationScreeningCharts	2019-04-11 00:19:55.212
223	/20190226005237-createMs1MigrationQueue	2019-04-14 23:40:56.069
224	/20190402044417-ms1Log	2019-04-14 23:40:56.087
225	/20190404070131-UpdateSurveyCodes	2019-04-14 23:40:56.099
226	/20190405055945-addMS1Metadata	2019-04-14 23:40:56.289
227	/20190408020403-AddFieldsToDHISSyncQueue	2019-04-14 23:40:56.567
228	/20190409033240-addMs1EndpointsToSurveys	2019-04-14 23:40:56.699
229	/20190410234158-AllowLegacyDisasterDataToExport	2019-04-14 23:40:56.786
230	/20190411003153-add-temanoku-metadata	2019-04-14 23:40:56.832
231	/20190411061555-resolvingMissingMS1FacilitiesPass1	2019-04-14 23:40:56.89
232	/20190411011052-FixNonPercentageChartsValueTypes	2019-04-16 01:10:25.142
233	/20190416000644-FixChartLegendsValueTypes	2019-04-16 01:10:25.16
234	/20190416054350-AddmSupplyRolloutMapOverlays	2019-04-26 06:13:21.492
235	/20190418043045-AddIvoryCoastmSupplyReports	2019-04-26 06:13:21.516
236	/20190423235726-AddCIV	2019-04-26 06:13:21.921
237	/20190426002606-AddIvoryCoastPointBounds	2019-04-26 06:13:21.942
238	/20190426014035-SeparateYamoussoukro	2019-04-26 06:13:21.961
239	/20190426052826-RemoveBelierEntityFromIvoryCoast	2019-04-26 06:13:21.97
240	/20190508054522-AddAbidjanRegionToCI	2019-05-17 05:47:06.76
241	/20190508234849-AddFacilityTypesForCI	2019-05-17 05:47:06.784
242	/20190509061337-FixAddFacilityTypesForCIMigration	2019-05-17 05:47:06.816
243	/20190510002605-CalculateBoundsForAbidjanRegion	2019-05-17 05:47:06.855
244	/20190510040941-UseDataElementCodeForPEHSDrilldown	2019-05-17 05:47:06.895
245	/20190510045056-RenameMonthlyDataValuesDataBuilder	2019-05-17 05:47:06.917
246	/20190510064134-DefineDataSourcesExplicitly	2019-05-17 05:47:07.022
247	/20190510064317-ConvertPercentageInGroupToNoSqlView	2019-05-17 05:47:07.082
248	/20190521050519-FixPEHSRawDownloads	2019-05-21 06:24:11.882
249	/20190521000001-AllowDonorLevelAccessMSUPOverlays	2019-05-22 04:22:54.577
250	/20190521000002-MoveBarChartBarsConfigOutOfPresentationOptions	2019-05-22 04:22:54.601
251	/20190521000003-AddTongaCommunityHealthMedicationReport	2019-05-22 04:22:54.617
252	/20190521000004-AddPeriodGranularityAndSumTotalForCHDressingsReport	2019-05-22 04:22:54.627
253	/20190521000005-AddTongaCHWeeklyHomeVistsReport	2019-05-22 04:22:54.65
254	/20190521000006-AddTongaCHRiskFactorsInDMHTNReport	2019-05-22 04:22:54.667
255	/20190521000007-UseRegionalDataForTongaRiskFactorsReport	2019-05-22 04:22:54.688
256	/20190521000008-AddTongaCHRiskFactorsReportToFacilityLevel	2019-05-22 04:22:54.704
257	/20190521000009-RenameIsDenominatorAnnualToFillEmptyValues	2019-05-22 04:22:54.722
258	/20190521000010-UpdateDmHtnMedicationReports	2019-05-22 04:22:54.735
259	/20190521000011-UseSumAllDataBuilderForClinicDressings	2019-05-22 04:22:54.763
260	/20190521000012-AddCHWeeklyHomeVisitsToFacilityAndCountry	2019-05-22 04:22:54.775
261	/20190521000013-RenameBarConfigToChartConfig	2019-05-22 04:22:54.797
262	/20190521000014-RemoveRiskFactorsReportTongaCH	2019-05-22 04:22:54.812
263	/20190522000836-AddValuesOfInterestToConfig	2019-05-22 04:22:54.821
264	/20190521050929-AddTongaRHFamilyPlanningAnnualContraceptives	2019-05-22 23:45:13.22
265	/20190522002836-AddTongaRhFamilyPlanningTfhaReport	2019-05-22 23:45:13.237
266	/20190522011700-AddTongaRhAdministrativeSchoolDataReport	2019-05-22 23:45:13.247
267	/20190522013335-AddTongaRhChildhoodImmunizationCoverageReport	2019-05-22 23:45:13.271
268	/20190522024121-AddTongaRhMaternalImmunizationCoverageReport	2019-05-22 23:45:13.287
269	/20190522030931-AddTongaRhSchoolImmunizationCoverageReport	2019-05-22 23:45:13.298
270	/20190522044630-AddTongaRhAnnualTotalPregnaciesByAgeReport	2019-05-22 23:45:13.305
271	/20190522052450-AddTongaRhAnnualPostnatalClinicCoverageReport	2019-05-22 23:45:13.315
272	/20190522061547-AddTongaRhAnnualPopulationBreakdownReport	2019-05-22 23:45:13.323
273	/20190522071354-AddTongaRhAnnualPopulationBreakdownHouseholdsReport	2019-05-22 23:45:13.332
274	/20190522072314-AddTongaRhAnnualMaternalDeaths	2019-05-22 23:45:13.342
275	/20190522073623-AddTongaRhAnnualGeneralMortality	2019-05-22 23:45:13.35
276	/20190522064645-AddMoreCIFacilityCoordinates	2019-05-23 01:31:14.734
277	/20190522235057-AddMissingCIFacilityEntitiesV2	2019-05-23 01:31:14.85
278	/20190523021512-UpdateYamoussoukroStorageFacilityTypeName	2019-05-23 03:35:48.553
279	/20190410231841-AddAPIClientsTable	2019-05-28 07:59:33.799
280	/20190415011159-AddClinicCodeConstraint	2019-05-28 07:59:33.831
281	/20190415064339-AddEntityColumnToSurveyResponse	2019-05-28 07:59:33.849
282	/20190523061000-ConvertSecretKeyToSecretKeyHash	2019-05-28 07:59:33.856
283	/20190528050830-ChangeBadRequestDefault	2019-05-28 08:13:47.467
284	/20190523025115-AddTongaChDmAndHtnPrevalenceReport	2019-05-30 05:13:00.327
285	/20190524000317-RenameFillEmptyValuesToFillEmptyDenominatorValues	2019-05-30 05:13:00.352
286	/20190524010538-AddTongaChDmAndHtnIncidenceReport	2019-05-30 05:13:00.367
287	/20190524015629-AddPercentageValueTypeInReports	2019-05-30 05:13:00.378
288	/20190530004611-AddHealthPromotionUnitValidationDashboard	2019-05-30 05:13:00.412
289	/20190529010604-UpdateIHRMapOverlayMeasures	2019-05-30 06:27:20.131
290	/20190530054820-AddCIBelier50Coordinates	2019-05-30 06:27:20.386
291	/20190530024804-AddTongaHpuMonthlyNationalQuitlineReport	2019-05-31 06:22:22.804
292	/20190530035136-AddTongHpuMonthlyNationalQuitlineNewCallsReport	2019-05-31 06:22:22.822
293	/20190530041126-AddTongaHpuMonthlyNutritionCounsellingReport	2019-05-31 06:22:22.836
294	/20190530043553-AddTongaHpuMonthlyNutritionCounsellingSessionsReport	2019-05-31 06:22:22.854
295	/20190531071226-updateSurveyCodesMS1	2019-06-04 02:44:36.183
296	/20190603033404-RemoveIsDataRegionalColumn	2019-06-04 02:44:36.268
297	/20190603040126-ConvertCaseIsDataRegional	2019-06-04 02:44:36.336
298	/20190604022445-SetDefaultIntegrationMetadata	2019-06-04 02:44:36.346
299	/20190530045142-AddTongaHpuBaselineQuitlineCaseLoadReport	2019-06-04 10:10:11.952
300	/20190603044757-AddTongaChNcdCasesReport	2019-06-04 10:10:11.982
301	/20190603045839-AddTongaChNewlyDiagnosedDmAndHtnCasesReport	2019-06-04 10:10:12.001
302	/20190603054719-AddTongaHpuMonthlyTvRadioAndSocialMedia	2019-06-04 10:10:12.013
303	/20190603065450-AddTongaHpuMonthlyPhysicalActivityReport	2019-06-04 10:10:12.039
304	/20190604045359-FixNcdCasesReport	2019-06-04 10:10:12.064
305	/20190604073505-AddTongaHpuMonthlyPhysicalActivityDrillDownReport	2019-06-04 13:12:17.111
306	/20190604074848-AddTongaHpuNcdRiskFactorScreeningEventReport	2019-06-04 13:12:17.128
307	/20190604080957-AddTongaHpuMonthlyIecDistributionReport	2019-06-04 13:12:17.143
308	/20190604085921-AddTongaHpuMonthlyTrainingsAndHealthTalksReport	2019-06-04 13:12:17.167
309	/20190604093044-AddTongaHpuMonthlyIecDistributionDrillDownReport	2019-06-04 13:12:17.209
310	/20190604093502-AddTongaHpuMonthlyTrainingsAndHealthTalksDrillDownReport	2019-06-04 13:12:17.235
311	/20190604104305-AddHP06ValidationReport	2019-06-04 13:12:17.252
312	/20190604105441-AddTongaHpuNcdRiskFactorScreeningEventDrillDownReport	2019-06-04 13:12:17.261
313	/20190604123857-ConsolidateSettingTypeCategoryInMonthlyPhysicalActivityReport	2019-06-17 05:59:10.861
314	/20190605004854-AddProgramCodeToHP07	2019-06-17 05:59:10.878
315	/20190605010756-AddTotalsToSpecificCategoriesHP06	2019-06-17 05:59:10.893
316	/20190605072511-RemovePeriodGranularityDrillDown	2019-06-17 05:59:10.905
317	/20190605073057-RefactorAndRenamePercentagesByGroup	2019-06-17 05:59:10.946
318	/20190607034703-RenameDataSourceTypeValues	2019-06-17 05:59:10.972
319	/20190607071742-RenameDataSourceCodeToCodes	2019-06-17 05:59:10.997
320	/20190611030359-RenameDataSourcesToDataServices	2019-06-17 05:59:11.017
321	/20190612002911-AddTongaChDmAndHtnComplicationsScreeningCompletionReport	2019-06-17 05:59:11.036
322	/20190613040018-AddDropOutCasesInMonthlyNationQuitlineReport	2019-06-17 05:59:11.094
323	/20190613054549-AddOptionInMonthlyIecDistributionReport	2019-06-17 05:59:11.127
324	/20190524063055-GeographicalAreaOrganisationUnitCodes	2019-06-19 03:07:31.905
325	/20190617015944-RemoveNotificationsFromUserSessionTable	2019-06-19 03:07:31.981
326	/20190613063847-AddTongaCH4ValidationReport	2019-06-21 06:40:50.561
327	/20190613081700-AddTongaCH11ValidationReport	2019-06-21 06:40:50.585
328	/20190619234449-ConvertTongaClinicTypeToNursingClinic	2019-06-21 06:40:50.601
329	/20190620052141-FixCH4ValidationReport	2019-06-21 06:40:50.639
330	/20190621020100-ConvertTongaNursingClinicsBackToClinics	2019-06-21 06:40:50.736
331	/20190621051307-AddMissingVanuatuGeojson	2019-06-21 06:40:50.958
332	/20190614031144-AddQuestionHook	2019-06-21 06:42:35.765
333	/20190619061923-AddGeolocateAndPhotoHooks	2019-06-21 06:42:35.804
334	/20190619060547-CreateEntityRelationTable	2019-06-28 07:06:34.06
335	/20190625060002-AddUniqueConstraintsForUpsert	2019-06-28 07:06:55.007
336	/20190626011143-CascadeUserDeletesToApiLog	2019-06-28 07:06:57.634
337	/20190626043217-MakeQuestionCodeUnique	2019-06-28 07:07:03.666
338	/20190628025659-Ms1UpdateFacilities	2019-06-28 07:07:05.354
339	/20190522044520-AddImmsFridgeStatReports	2019-07-12 07:31:15.865
340	/20190528063807-AddImmsVaccineSoHReport	2019-07-12 07:31:15.9
341	/20190531033900-AddVerySpecificTongaVillagesServicedReport	2019-07-12 07:31:15.924
342	/20190620062126-AddCodeForImmunisationDashboardGroups	2019-07-12 07:31:15.95
343	/20190620062157-AddFridgeBreachesReport	2019-07-12 07:31:16.028
344	/20190625014307-VUVaccinesPortalSurveyVisualistations	2019-07-12 07:31:16.088
345	/20190626021701-AddTongaPopulationMapOverlays	2019-07-12 07:31:16.11
346	/20190629021415-FixUserGoupForImmunisationDashboard	2019-07-12 07:31:16.136
347	/20190629065125-InsertCorrectReportsInImmunisationFacility	2019-07-12 07:31:16.172
348	/20190629085943-AddTemperatureBreachesMapOverlay	2019-07-12 07:31:17
349	/20190630013836-AddProgramCodeToImmsSOH	2019-07-12 07:31:17.06
350	/20190630020107-AddImmsSOHAtFacilityLevel	2019-07-12 07:31:17.133
351	/20190630083038-ImmsStockoutsFacility	2019-07-12 07:31:17.221
352	/20190630083253-AddMissingVaccine	2019-07-12 07:31:17.235
353	/20190630084135-AddFridgeDailyTemperaturesReport	2019-07-12 07:31:17.268
354	/20190630135821-StripQuantityFromStartOfStockouts	2019-07-12 07:31:17.314
355	/20190630140921-MakeStockoutMultiSingleValue	2019-07-12 07:31:17.372
356	/20190630141834-MakeStockoutMultiSingleValueTakeTwo	2019-07-12 07:31:17.392
357	/20190630203941-SetValueTypeTempReport	2019-07-12 07:31:17.42
358	/20190701022046-AlterMapOverlayId	2019-07-12 07:31:17.624
359	/20190701022106-AddBreachesXStockOnHandMapOverlay	2019-07-12 07:31:17.751
360	/20190705040038-RemoveTTVaccineFromReports	2019-07-12 07:31:17.769
361	/20190709003722-RenameAndRefactorOrganisationUnitMatrix	2019-07-12 07:31:17.888
362	/20190709003729-ShowFacilitiesInVaccineCountReport	2019-07-12 07:31:17.941
363	/20190709062420-UpdateTongaHouseholdsOverlayId	2019-07-12 07:31:17.961
364	/20190709063035-AddReferenceLinesToFridgeTemperatureChart	2019-07-12 07:31:17.975
365	/20190711001559-RenameBreachesXStockOnHand	2019-07-12 07:31:18.035
366	/20190711233304-ChangeVaccineCountMatrixToDoses	2019-07-12 07:31:18.068
367	/20190708001046-RemoveGeoFromNotify	2019-07-15 05:06:10.733
368	/20190708001047-AddNotificationForEntityType	2019-07-29 23:59:00.301
369	/20190719043256-SetMetadataToJSONB	2019-07-29 23:59:00.752
370	/20190719043257-UpdateCodeToId	2019-07-29 23:59:06.302
371	/20190723000023-DeleteCodeBasedEntityChanges	2019-07-29 23:59:10.953
372	/20190725013154-AddWISHEnities	2019-07-29 23:59:11.312
373	/20190712040027-UseMultipleProgramCodesForSoh	2019-07-30 03:09:19.514
374	/20190719032936-AddScaleTypeToCriticalMedicinesMapOverlay	2019-07-30 03:09:19.528
375	/20190719062018-ChangeTBTreatmentReportsDataSource	2019-07-30 03:09:19.538
376	/20190724044344-ChangeHouseholdsToSpectrumType	2019-07-30 03:09:19.547
377	/20190724065622-UnpluraliseImmuninsationsMapOverlayGroup	2019-07-30 03:09:19.574
378	/20190725022427-MergeImmsAndColdChainMapOverlayGroups	2019-07-30 03:09:19.608
379	/20190730060121-AddAggregationTypesToPercentageByPairs	2019-08-02 00:59:38.028
380	/20190725233059-UseEntityAttributesInSyncRecords	2019-08-21 23:38:52.566
381	/20190726005711-TransformEntityMetadataToDeepObject	2019-08-21 23:38:52.683
382	/20190728232315-SetDefaultValueForChangeDetailsToEmptyObject	2019-08-21 23:38:52.981
383	/20190730064726-DitchClinicId	2019-08-21 23:39:04.398
384	/20190731055620-AddMissingEntitiesToSyncQueue	2019-08-21 23:52:25.847
385	/20190801023410-RemoveIsFromRepeatingSurvey	2019-08-21 23:52:35.298
386	/20190813055649-RestructureCoteDivoire	2019-08-21 23:52:35.47
387	/20190814001242-AddConfigToComponents	2019-08-21 23:52:35.77
388	/20190806041106-ChangeServiceStatusReportNameAtFacilityLevel	2019-09-12 03:42:42.098
389	/20190808052641-AddMonthPeriodGranularityToReproductiveHealthVisitsbsbyTypeperMonthChart	2019-09-12 03:42:42.116
390	/20190809002248-UsePreaggregatedValuesForVaccineStockOnHand	2019-09-12 03:42:42.13
391	/20190813003811-ChangeMouseoverInfoForAverageAvailabilityMedicinesReport	2019-09-12 03:42:42.151
392	/20190815062340-AddWISHDataDownloads	2019-09-12 03:42:42.169
393	/20190816041256-UpdateStockoutsReportToUsePreaggregatedValues	2019-09-12 03:42:42.201
394	/20190819024920-FilterNoDataByDefaultFridgeBreachOverlays	2019-09-12 03:42:42.213
395	/20190904045009-RemoveProgramCodeFromVaccineSoHReport	2019-09-12 03:42:42.242
396	/20190906002434-RemoveMedicinesAvailabilityForWorld	2019-09-12 03:42:42.278
397	/20190916234616-AddCommunicableDiseasesValidationDashboard	2019-09-23 06:25:18.88
398	/20190920020842-AddCD1ValidationReport	2019-09-23 06:25:18.928
399	/20190920022005-AddCD2aValidationReport	2019-09-23 06:25:18.972
400	/20190920022020-AddCD2bValidationReport	2019-09-23 06:25:19.014
401	/20190920022026-AddCD2cValidationReport	2019-09-23 06:25:19.047
402	/20190920022027-AddCD3ValidationReport	2019-09-23 06:25:19.102
403	/20190920022028-AddCD4ValidationReport	2019-09-23 06:25:19.13
404	/20190920022029-AddCD5ValidationReport	2019-09-23 06:25:19.153
405	/20190920022030-AddCD6ValidationReport	2019-09-23 06:25:19.176
406	/20190920022031-AddCD7ValidationReport	2019-09-23 06:25:19.21
407	/20190902013112-WISHVillageUpdate	2019-09-24 00:52:49.498
408	/20190924040432-StripTongaFromCDCodes	2019-09-24 06:27:15.589
409	/20190924041100-StripTongaFromCDCodes	2019-09-24 06:28:39.273
410	/20190925230725-AddCaseEntityType	2019-09-26 06:27:48.592
411	/20191004061449-TongaCD1Tweaks	2019-10-07 05:10:53.046
412	/20191004065952-TongaCD5Tweaks	2019-10-07 05:10:53.07
413	/20191004071328-TongaCD4Tweaks	2019-10-07 05:10:53.131
414	/20191004071540-TongaCD2Tweaks	2019-10-07 05:10:53.257
415	/20190930235110-AddDHISParamsForMS1	2019-10-10 04:12:31.96
416	/20191004060225-SyncMissedEventBasedDeletes	2019-10-10 04:12:32.162
417	/20191008045126-AddIsDataRegionalInEntityMetadata	2019-10-15 02:45:31.477
418	/20191011013237-TongaCD2ICD10CodeChanges	2019-10-15 04:09:33.902
419	/20191017025014-FPValidationReportAtIslandGroups	2019-10-17 04:15:12.631
420	/20191017211946-AddFullFPValidationNationalDistrict	2019-10-18 05:26:25.369
421	/20191021021359-MS1TimelinessMapOverlay	2019-10-21 02:24:54.612
422	/20191021002826-AddMissingDeletedAnswersToSyncQueue	2019-10-21 05:34:47.778
423	/20191022002521-AddCD3aValidationReport	2019-10-25 05:22:20.434
424	/20191022002522-AddCD3bValidationReport	2019-10-25 05:22:20.485
425	/20191022234831-AddVaccineDashboardsToSolomons	2019-10-25 05:22:20.5
426	/20191023013025-AddPneumococcolVaccineToDashboards	2019-10-25 05:22:20.519
427	/20191023013111-AddVaccineMapOverlaysToSolomons	2019-10-25 05:22:20.532
428	/20191023023249-ChangeVanuatuEPIPermissionGroupToJustEPI	2019-10-25 05:22:20.545
429	/20191021215518-FixEntityIsDataRegional	2019-10-25 05:25:02.897
430	/20191028014344-AddStriveDashboard	2019-10-28 22:44:43.246
431	/20191028014345-AddDnaExtractionRecordReport	2019-10-28 22:44:43.325
432	/20191106053817-UseEntityIdsInSCRF	2019-11-11 04:01:26.644
433	/20191104075102-AddWeeklyReportedCasesReport	2019-11-11 06:22:34.42
434	/20191106001633-AddDataSourceKeyInDataBuilders	2019-11-11 06:22:34.511
435	/20191106024434-AddStriveFacilityLevelDashboardGroup	2019-11-11 06:22:34.539
436	/20191107005427-AddStriveCRFCaseClassificationsReport	2019-11-11 06:22:34.568
437	/20191107023843-AddStriveFebrileCasesBySexReport	2019-11-11 06:22:34.603
438	/20191107222443-AddSCRFRDTByResultsReport	2019-11-11 06:22:34.631
439	/20191111002915-AddFebrileIllnessByAgeGroupReport	2019-11-11 06:22:34.66
440	/20191112032026-ResyncEntityAnswers	2019-11-14 22:10:21.008
441	/20191114025038-UpdatePositiveMixedStriveQuestion	2019-11-14 22:10:21.118
442	/20191112024821-AddWeeklymRDTPositiveReport	2019-11-14 22:11:48.485
443	/20191112035536-AddWeeklyNumberOfConsultationsReport	2019-11-14 22:11:48.61
444	/20191114033625-UpdateSCRFRDTByResultsReport	2019-11-14 22:11:48.629
445	/20191115042821-AddVanuatuBirths	2019-11-18 00:52:06.285
446	/20191114232355-AddProjectTable	2019-11-20 21:36:44.295
447	/20191118044355-OperationalFacilitiesNotPublic	2019-11-20 21:36:44.34
448	/20191114222903-ChangePeriodTypeChValidationReports	2019-11-25 06:10:30.728
449	/20191119221519-UpdateProjectDefaultTheme	2019-11-25 06:10:30.758
450	/20191121001602-UpdateProjectTableEntityColumn	2019-11-25 06:10:30.781
451	/20191125001343-RemoveVUBirthsDashboard	2019-11-25 06:10:30.855
452	/20191126010956-UpdateStriveReports	2019-11-27 22:52:07.22
453	/20191114002413-DefineViewTypeForMatrix	2019-12-03 01:17:46.037
454	/20191118225434-AddWeeklyFebrileCasesReport	2019-12-03 01:17:46.169
455	/20191126003747-AddWeeklyPercentageOfPositiveMalariaConsultationsReport	2019-12-03 01:17:46.231
456	/20191126234147-AddWeeklyPercentageOfPositiveMalariaAgainstConsultationsReport	2019-12-03 01:17:46.276
457	/20191203020146-AddStriveCustomDataDownloads	2019-12-03 02:54:34.039
458	/20191202054031-AddTotalMeaslesCasesByDistrictRadius	2019-12-03 05:31:16.044
459	/20191203014952-AddTotalMeaslesCasesByDistrictSpectrum	2019-12-03 05:31:16.095
460	/20191203215238-ChangePositiveCountCalculation	2019-12-03 22:32:11.883
461	/20191203041304-AddMeaslesCasesByGender	2019-12-04 05:41:04.242
462	/20191203051650-AddMeaslesCasesByAgeGroup	2019-12-04 05:41:04.318
463	/20191203054012-UpdateMeaslesOverlayNames	2019-12-04 05:41:04.329
464	/20191204020310-AddCD8ValidationReport	2019-12-04 05:41:04.367
465	/20191204032509-HeatmapColorGradient	2019-12-04 05:41:04.378
466	/20191206003710-RenameSumDataBuilders	2019-12-06 07:27:56.012
467	/20191206025531-AddCD8ValidationReportAtCountryLevel	2019-12-06 07:27:56.129
468	/20191206053437-AddMeaslesCasesPer10kPax	2019-12-06 07:27:56.191
469	/20191206064413-AddPercentageValueTypeForCriticalItemAvailability	2019-12-06 07:27:56.201
470	/20191210002602-CD3bRemoveDateSelector	2019-12-12 00:18:00.546
471	/20191114030520-FixImportDeleteCountsForUpdates	2019-12-12 00:26:42.232
472	/20191114044010-SingleDhisReferencePerRecord	2019-12-12 00:26:45.795
473	/20191212221249-UpdateSTRIVEPermissions	2019-12-13 05:05:39.287
474	/20191210055005-CoconutRewardUpdate	2019-12-17 23:27:40.851
475	/20191127033638-ChangeSiteColumnConfig	2019-12-18 21:52:56.168
476	/20191216015926-RemoveOrgUnitIsGroupFromConfig	2019-12-18 21:52:56.192
477	/20191216220622-RemoveVitiLevuRegionFromFiji	2019-12-18 21:52:56.251
478	/20191216041125-ResyncVillagesAsOrgUnits	2019-12-18 23:06:40.746
479	/20191213030728-UpdateSTRIVEDashboardNames	2019-12-19 00:45:13.03
480	/20191216225125-UpdateWeeklyFebrileCasesReportName	2019-12-19 00:45:13.05
481	/20191216233942-UpdatePositiveMalariaConsultationsReport	2019-12-19 00:45:13.063
482	/20191216235755-ChangeSTRIVEWeeklyReportedCasesReportName	2019-12-19 00:45:13.077
483	/20191216002240-MapOverlayPercentage	2019-12-19 05:49:15.025
484	/20191217044009-TongaVillageAnswersToEntityIds	2019-12-20 06:46:51.008
485	/20191218040525-TongaVillageAnswersToPrimaryEntities	2019-12-20 06:46:56.316
486	/20191219231942-TongaCD3CaseParentsToVillages	2019-12-20 06:46:56.678
487	/20191220032822-DeleteTongaVillageAnswers	2019-12-20 06:46:58.623
488	/20191118051744-RenameViewModeDashboardGroupColumn	2019-12-20 06:48:15.211
489	/20191121231722-AddProjectCodeForeignKeyForDashboardGroups	2019-12-20 06:48:15.321
490	/20191208223633-AddDefaultMeasureColumnToProjectTable	2019-12-20 06:48:15.349
491	/20191208223643-RemoveProjectCodeFromDashboardGroupsAndAddDashboardGroupNameToProjects	2019-12-20 06:48:15.373
492	/20191208223743-AddProjectsToTable	2019-12-20 06:48:15.431
493	/20191208233743-AddUnfpaDashboardGroups	2019-12-20 06:48:15.491
494	/20191208233747-AddUnfpaMethodsAvailableCharts	2019-12-20 06:48:15.617
495	/20191209031534-AddUNFPARHContraceptiveMethodsOfferedReports	2019-12-20 06:48:15.651
496	/20191209061626-AddUnfpaFacilitiesOfferingServicesAndDelivery	2019-12-20 06:48:15.746
497	/20191217043147-RemoveThemeAndAddLogoProjectColumns	2019-12-20 06:48:15.756
498	/20191217051444-UpdateProjectImageUrls	2019-12-20 06:48:15.773
499	/20191220004141-UpdateProjectUserGroups	2019-12-20 06:48:15.787
500	/20191219040555-ShowEventOrgUnitInTongaCDReports	2019-12-23 22:58:29.845
503	/20191221032822-UseOriginalTimezoneForDateAnswers	2019-12-29 22:12:32.173
504	/20191230030956-UseVillageInCH4Report	2020-01-14 04:36:03.125
505	/20200102222808-AddTongaUNFPADashboardGroupsAndReports	2020-01-14 04:36:03.199
506	/20200103035630-UseVillageInCH11Report	2020-01-14 04:36:03.564
507	/20200103041050-AddUNFPAStockCardReports	2020-01-14 04:36:03.63
508	/20200103051018-MakeCHValidationReportIdsConsistent	2020-01-14 04:36:04.697
509	/20200106033541-AddEntityTypeInCDOverlays	2020-01-14 04:36:04.805
510	/20200107043937-RemoveColumnFromCD3aReport	2020-01-14 04:36:04.853
511	/20200109052723-ConsolidatePNGCaseReportFormExportDateColumns	2020-01-16 19:28:42.56
512	/20191218232516-EmailConfirmation	2020-01-21 21:03:51.508
513	/20200109231002-AddLabelTypeToViewJsonOnReports	2020-01-21 21:03:51.571
514	/20200114105007-PercentageEventCountsBuildersUseFractionAndPercentageLabel	2020-01-21 21:03:51.598
515	/20200115052004-AddTongaAndMicronesiaToUnfpaProjectCountries	2020-01-21 21:03:51.764
516	/20200114233039-AddFMUnfpaDashboardGroup	2020-01-23 04:41:01.57
517	/20200110032903-ConvertSingleColumnTableTO-CHDashboardReportsToTableOfDataValues	2020-02-04 03:03:39.028
518	/20200113052422-ConvertTableFromDataElementGroupsTO-CHDashboardReportsToTableOfDataValues	2020-02-04 03:03:39.084
519	/20200115003324-ConvertTO-RHDashboardReportsToTableOfDataValues	2020-02-04 03:03:39.218
520	/20200117042010-ConvertRemainingTODashboardReportsToTableOfDataValues	2020-02-04 03:03:39.325
521	/20200129031634-ChangeNoCountryCode	2020-02-04 03:03:39.339
522	/20200129031728-AddNewCountriesToEntityTable	2020-02-04 03:03:39.399
523	/20200131041935-DeleteRedundantImmsBreaches	2020-02-04 03:05:23.343
524	/20200202205145-DeleteTongaSpecificDashboardsFromDemoLand	2020-02-04 20:41:17.744
525	/20200128054247-UsePerOrgUnitDataBuilderForUNFPAStockCardsReport	2020-02-06 22:32:27.446
526	/20200123233519-UnfpaStaffTrainingDashboard	2020-02-13 01:01:20.644
527	/20200129040859-InsertIHRWorldDashboardGroup	2020-02-13 01:01:20.708
528	/20200131023339-ContraceptionDashboardUpdate	2020-02-13 01:01:20.767
529	/20200205015401-DeleteCD2-2Answers	2020-02-13 01:01:20.979
530	/20200206214233-AddColumnsToApiRequestLog	2020-02-13 01:01:41.369
531	/20200206214234-RenameAndCleanupInstallId	2020-02-13 01:01:42.451
532	/20200206221246-AddColumnsToMeditrakDevice	2020-02-13 01:01:42.58
533	/20200206221247-AddMeditrakDeviceIdToRefreshToken	2020-02-13 01:01:42.728
534	/20200206221249-AddRefreshTokenToApiRequestLog	2020-02-13 01:01:42.825
535	/20200207044948-AddBonrikiEastToMs1Api	2020-02-13 01:01:42.858
536	/20200207045423-IHRSparReportingCountries	2020-02-13 01:01:42.884
537	/20200210233650-SwitchRowsAndColsForTongaFP01	2020-02-13 01:01:43.71
538	/20200214025142-UpdateStriveWeeklyMRDTPositiveConfig	2020-02-14 04:29:20.453
539	/20200212220350-optimiseWorldFetchData	2020-02-21 01:49:23.321
540	/20200220231953-DeleteSubmissionDateColumnsCD1CD2	2020-02-21 01:49:23.504
541	/20200129040800-InsertIHRCountryReport	2020-02-25 02:34:20.799
542	/20200219235149-AddIHRReportBAndAddBothToGroup	2020-02-25 02:34:20.871
543	/20200224235334-SPARReportHeader	2020-02-25 02:34:20.912
544	/20200116211310-AddDataSourceTable	2020-02-25 06:32:54.799
545	/20200122003753-ConvertDataElementToCodeInSyncLog	2020-02-25 06:34:46.657
546	/20200128021719-AddTongaDataSources	2020-02-25 06:34:52.487
547	/20200129211641-AvoidChangeTimeConflicts	2020-02-25 06:35:32.595
548	/20200204005927-AddDataElementDataGroupTable	2020-02-25 06:35:33.014
549	/20200205004208-AddTongaSurveysToDataSource	2020-02-25 06:35:34.554
550	/20200210004010-SimplifyChangeNotification	2020-02-25 06:35:34.635
551	/20200211002034-UpdateDataBuilders	2020-02-25 06:35:35.82
552	/20200218001344-UpdateMapOverlays	2020-02-25 06:35:36.08
553	/20200218025613-AddDataGroupsToDataSource	2020-02-25 06:35:36.393
554	/20200218215230-ResyncAllTongaData	2020-02-25 06:38:31.217
555	/20200224063900-UseSingleDataElementForDMHTNDenominator	2020-02-25 06:38:31.776
556	/20200224003036-AddIHRJEEMatrixReport	2020-02-26 06:05:41.669
557	/20200228013730-DeleteRedundantImmsBreaches	2020-02-28 02:41:25.468
558	/20200227001738-AddWeeklyNumberOfFebrileIllnessCasesByVillageReport	2020-03-03 01:20:17.167
559	/20200228040157-MoveAutocompletePrimaryEntityToEntityId	2020-03-03 01:20:17.278
560	/20200302202141-ReinstateBuildingRecordInChangeNotifier	2020-03-05 08:54:21.288
561	/20200305051343-ClearNullSyncQueueDetails	2020-03-05 08:54:22.972
562	/20200305053046-AddDataSourceForCD3b-014b-C19-9	2020-03-05 08:54:31.999
563	/20200303043257-PercentageOfValueCountsSplitCodesFromValueConfig	2020-03-11 04:55:06.369
564	/20200305043430-UpdateStockCardsReportConfig	2020-03-11 04:55:06.448
565	/20200310020604-MatrixTableNameChange	2020-03-11 04:55:06.488
566	/20200311003701-UpdateMatrixHeader	2020-03-11 04:55:06.547
567	/20200311013245-AddProgramCodeToHP05DrillDown	2020-03-11 04:55:06.65
568	/20200312003031-AddAggregationEntityTypeInMapOverlays	2020-03-17 02:50:54.528
569	/20200312223135-AddWeeklyReportedFebrileIllnessCasesToVillages	2020-03-17 02:50:55.835
570	/20200313000357-AddGeneralDashboardGroupToVillages	2020-03-17 02:50:56.013
571	/20200316010349-AddWeeklyNumberOfFebrileIllnessReportsNational	2020-03-24 05:41:33.358
572	/20200316022146-AddStriveRegionalDashboardGroup	2020-03-24 05:41:33.414
573	/20200316022217-AddWeeklyNumberOfFebrileIllnessReportsRegional	2020-03-24 05:41:33.527
574	/20200316042719-AddMRDTDashboardReportToNationalAndProvincial	2020-03-31 07:11:24.146
575	/20200316055056-Add2YAxisMRDTFebrileIllnessDashboardReportToNationalAndProvincialStrive	2020-03-31 07:11:24.247
576	/20200318223935-DeleteErroneousStriveSurveyData	2020-03-31 07:11:24.303
577	/20200323002803-AddCovid19AustraliaToProjects	2020-03-31 07:20:42.006
578	/20200324032850-AddCOVID19DashboardgroupsAusNationalState	2020-03-31 07:20:42.109
579	/20200324050422-AddCovid19StateDashboardReport	2020-03-31 07:20:42.167
580	/20200324053202-AddCasesByStateReportCovidAus	2020-03-31 07:20:42.238
581	/20200325001848-AddTotalNumberReportedCasesCOVIDAUMapOverlay	2020-03-31 07:20:42.27
582	/20200326012240-MoveDefaultDashboardGroupsToIndividualCountries	2020-03-31 07:20:42.62
583	/20200326032657-AddTotalCasesByStateAus	2020-03-31 07:20:42.685
584	/20200326034630-AddTotalCovidCasesByTypeReport	2020-03-31 07:20:42.741
585	/20200326043343-AddCovidNewCasesByDayBarChartStateAus	2020-03-31 07:20:42.813
586	/20200326045458-AddCovid19NationalDailyCasesOverTimeEachStateAndTotalDashboard	2020-03-31 07:20:42.922
587	/20200326225508-FixDailyCovidStateNumbersReportAus	2020-03-31 07:20:42.968
588	/20200326233613-FixDailyCovidCasesByStateChart	2020-03-31 07:20:43.004
589	/20200327014704-AddNationalNewCovidCasesByDayAus	2020-03-31 07:20:43.106
590	/20200327052900-UpdateCovidAuTotalConfirmedCasesMapOverlayScaleMin	2020-03-31 07:20:43.126
591	/20200327055605-UpdateCovidAuTotalConfirmedCasesOverTimeByStateWordings	2020-03-31 07:20:43.177
592	/20200330013822-ChangeGeographicalBoundsOfWorld	2020-03-31 07:20:43.211
593	/20200330014731-MoveDefaultMapOverlaysToIndividualCountries	2020-03-31 07:20:43.315
594	/20200330023425-AddDailyToCovid19Reports	2020-03-31 07:20:43.343
595	/20200330025955-ChangeIdOfDashboardReportToRemoveState	2020-03-31 07:20:43.392
596	/20200330034009-AddSubDistrictAndFacilityLevelDashboardGroups	2020-03-31 07:20:43.429
597	/20200330034023-AddLinkToSourcesCovidAllOrgLevels	2020-03-31 07:20:43.463
598	/20200330041343-RemoveRecoveriesFromDashboardCovid	2020-03-31 07:20:43.489
599	/20200330233911-ChangeDefaultDataToYesterdayCovidReports	2020-03-31 07:20:43.515
600	/20200317055123-AddStriveReportsToVillages	2020-04-07 04:56:55.638
601	/20200325044717-MakeFebrileIllnessCaseCalculationConsistent	2020-04-07 04:56:55.711
602	/20200403020133-UpdateDataSourcetoReflectHP01andHP02Changes	2020-04-07 04:56:56.472
603	/20200407021657-AddDisasterDashboardGroupForVanutatu	2020-04-07 04:56:56.557
604	/20200324034720-CreateMSupplyUNFPAMatrices	2020-04-20 02:20:13.418
605	/20200325002500-RefactorOrganisationUnitTableReportsToTableOfValueForOrgUnits	2020-04-20 02:20:13.705
606	/20200330044935-AddConfigToIHRReportsForOrgUnitColumns	2020-04-20 02:20:13.744
607	/20200401220823-RemoveWordTodayFromCovidReports	2020-04-20 02:20:13.807
608	/20200402024847-AddProjectEntity	2020-04-20 02:20:18.061
609	/20200402024848-CreateProjectHierarchy	2020-04-20 02:20:18.307
610	/20200403015828-AddCovidRawDataDownloadTonga	2020-04-20 02:20:18.356
611	/20200403030413-AddPeriodDataSwitchToDashBoardReports	2020-04-20 02:20:18.451
612	/20200405231416-AddIpcCommodityAvailabilityReport	2020-04-20 02:20:19.08
613	/20200406000236-AddFacilityCommoditiesOverlays	2020-04-20 02:20:19.235
614	/20200406062057-AddCovidICUAndIsolationBedsOverlaysTonga	2020-04-20 02:20:19.28
615	/20200407002449-AddStriveStackedBarmRDTByResultReport	2020-04-20 02:20:19.331
616	/20200407052132-AddSOHandAMCMatricesToUNFPA	2020-04-20 02:20:19.532
617	/20200408054558-AddCaseContactEntityType	2020-04-20 02:20:20.888
618	/20200409013211-AddAddCovidTestsPerCapitaReport	2020-04-20 02:20:20.951
619	/20200409065901-AddStripFromDataElementNamesForUNFPAMatrices	2020-04-20 02:20:20.969
620	/20200415061542-AddStriveOverlayTotalConsultationsWTFBubble	2020-04-20 02:20:21.031
621	/20200416060614-UpdateMOSUnpfaMedicinesToTrafficLightsConfig	2020-04-20 02:20:21.049
622	/20200331033941-CreateUNFPADeliveryServicesLineCharts	2020-04-24 06:48:49.22
623	/20200403054119-SwapDataElementsForRHCStockCardsChart	2020-04-24 06:48:49.294
624	/20200408015324-AddTestsConductedDashboardAus	2020-04-24 06:48:50.08
625	/20200408052334-AddSamoaCovidRawDataDownloadDashboard	2020-04-24 06:48:50.208
626	/20200408065558-AddDenominatorAggregationFlagToUNFPAReport	2020-04-24 06:48:50.258
627	/20200416033713-ReplaceProvinceInDashboardGroup	2020-04-24 06:48:50.573
628	/20200416033714-ReplaceAndRemoveRegionEntityType	2020-04-24 06:49:06.988
629	/20200416033715-ReplaceRegionInMapOverlays	2020-04-24 06:49:07.184
630	/20200416033716-UseLowercaseOrgUnitLevel	2020-04-24 06:49:07.375
631	/20200416033717-ReplaceRegionInSurveyScreenComponent	2020-04-24 06:49:10.617
632	/20200416033718-RenameOrganisationUnitLevelInDashboardReport	2020-04-24 06:49:10.677
633	/20200406042212-AddCovidTotalDeathsVsCasesByDay	2020-04-27 23:26:41.019
634	/20200406044451-AddCovidCumulativeDeathsVsCases	2020-04-27 23:26:41.204
635	/20200409012830-Migrate-old-facility-BCD1-data	2020-04-27 23:26:41.921
636	/20200421000451-AddTongaCovidIpcCommodityAvailabilityDashboard	2020-04-27 23:26:42.244
637	/20200427015657-AddReproductiveHealthStockOverlays	2020-04-28 22:12:23.004
638	/20200428033101-RenamePngVillageCodes	2020-05-01 05:42:53.356
639	/20200428035406-UpdateUNFPACountriesAndDashboards	2020-05-01 05:42:56.096
640	/20200130050502-ReconcileClinicEntities	2020-05-12 05:53:40.85
641	/20200401030503-AddFacilityTypeMapOverlayForAustralia	2020-05-12 05:53:41.026
642	/20200401033652-RemoveAccessToOperationalFacilitiesForAU	2020-05-12 05:53:41.105
643	/20200427073641-AddUNFPAFacilityMosReport	2020-05-12 05:53:41.446
644	/20200428051149-AddUNFPADemoLandDashboardGroup	2020-05-12 05:53:41.536
645	/20200428051160-AddUNFPAReportToDLDashboardGroup	2020-05-12 05:53:41.597
646	/20200428063651-UpdateServiceListReportToHaveNewFilterConfig	2020-05-12 05:53:41.701
647	/20200428144225-UpdateCovidNewCaseByDayDataBuilderConfig	2020-05-12 05:53:41.813
648	/20200429010300-AddUNFPAReproductiveHealthProductAverageMonthlyConsumptionReport	2020-05-12 05:53:42.113
649	/20200429043336-AddCommunicableDiseasesDashboardGroup	2020-05-12 05:53:42.185
650	/20200429043517-AddSTITestStatusNumberOfPatientsTestedReport	2020-05-12 05:53:42.401
651	/20200430030959-UpdateWeeklyMalariaPerCasesDenominator	2020-05-12 05:53:42.452
652	/20200501000604-AddTongaDHIS2OutcomeOfContactTracing	2020-05-12 05:53:42.657
653	/20200504012216-ChangeFilterToCustomFilterInPercentagesOfValueCountsPerPeriodDataBuilderConfig	2020-05-12 05:53:42.781
654	/20200505143813-AddTongaDHIS2MedicalCertificatesDistributedReport	2020-05-12 05:53:43.201
655	/20200505222240-updateTongaPehsMatrixIncFacType	2020-05-12 05:53:43.305
656	/20200506040950-UpdateSumPerPeriodDataBuilderConfigInReports	2020-05-12 05:53:43.985
657	/20200507033858-AddAttributesToEntityTable	2020-05-12 05:53:54.462
658	/20200326052907-AddStriveReportFebrileIllnessAndRDTPositive	2020-05-13 03:13:08.331
659	/20200405234315-AddStriveReportFebrileCasesByWeek	2020-05-13 03:13:08.484
660	/20200406010511-AddRDTTotalTestsVsPercentagePositiveComposedReportStrive	2020-05-13 03:13:08.623
661	/20200406013942-AddStriveVillageFebrileIllessDiscreteShadedPolygonsMapOverlay	2020-05-13 03:13:08.687
662	/20200406061858-AddStriveVillagePercentMRDTPositiveShadedSpectrumMapOverlay	2020-05-13 03:13:08.745
663	/20200407044756-Add3TypeOfStriveVillagePercentMRDTPositiveShadedSpectrumMapOverlay	2020-05-13 03:13:08.84
664	/20200408002104-AddStriveFacilityRadiusOverlayTestNumber	2020-05-13 03:13:09.046
665	/20200408044353-Add4StriveMapOverlays	2020-05-13 03:13:09.378
666	/20200414065121-AddStriveOverlayPercentmRDTPositiveAndTestsSourceWTF	2020-05-13 03:13:09.515
667	/20200415034908-AddStriveOverlayAllCasesByFacilityBubbleCRF	2020-05-13 03:13:09.593
668	/20200424054821-ShiftAnnualFanafanaolaDashboardsToShowPreviousYearData	2020-05-13 03:13:09.662
669	/20200504025438-UseNumberValueForDataValueFilter	2020-05-13 03:13:09.751
670	/20200504065336-UseNumberForValueFilterInOverlays	2020-05-13 03:13:09.834
671	/20200512023653-UseNumberForValueFilterInReports	2020-05-13 03:13:09.938
672	/20200513022041-UpdateRdtTestsTotalConfig	2020-05-13 03:13:10.011
673	/20200430065532-AddTongaNotifiableDiseasesStackedBar	2020-05-13 05:15:17.737
674	/20200505233853-AddTongaIsolationAdmissionsInitialDiagnosisStackedBar	2020-05-13 05:15:18.125
675	/20200505234922-AddTongaSuspectedCasesNotifiableDiseasesStackedBar	2020-05-13 05:15:18.248
676	/20200506001638-AddTongaContactsTracedStackedBar	2020-05-13 05:15:18.376
677	/20200506041900-AddLabConfirmedSTICasesPerMonthReport	2020-05-13 05:15:18.471
678	/20200416023232-ShiftFanafanaolaDashboardsToShowPreviousMonthData	2020-05-18 05:15:38.271
679	/20200429021341-AddUNFPAReproductiveHealthProductsMonthOfStockReport	2020-05-18 05:15:38.491
680	/20200504224323-AddSchoolEntityType	2020-05-18 05:15:41.126
681	/20200520034215-RemoveDhisIntegrationMetadataForLaosSchoolsSurveys	2020-05-20 08:06:10.353
682	/20200505015116-AddEntityHierarchyIdToProjectTable	2020-05-22 04:53:18.839
683	/20200506031906-ChangeRootEntityToProjects	2020-05-22 04:53:20.049
684	/20200506224325-AddLaosSchoolsProject	2020-05-22 04:53:20.474
685	/20200507020955-AddLaosSchoolAlternativeHierarchyRelations	2020-05-22 04:53:35.326
686	/20200507070444-AddLaosSchoolsSchoolTypeMapOverlay	2020-05-22 04:53:35.509
687	/20200513054910-AddLaosSchoolsRadiusOverlays	2020-05-22 04:53:35.744
688	/20200513063247-AddLaosSchoolBinaryMeasureMapOverlays	2020-05-22 04:53:35.894
689	/20200513230725-AddLaosSchoolsDevPartnerOverlay	2020-05-22 04:53:36.095
690	/20200514014908-AddProjectDashboardGroups	2020-05-22 04:53:36.374
691	/20200514045247-RemoveWorldAsChildOfProjects	2020-05-22 04:53:36.667
692	/20200514144900-AddLaosSchoolNumberOfChildrenHeatMap	2020-05-22 04:53:36.845
693	/20200515041112-AddTupaiaToDataSourceServiceTypes	2020-05-22 04:53:41.052
694	/20200518011240-AddDevelopmentPartnerPinOverlay	2020-05-22 04:53:41.138
695	/20200518035908-AddDefaultValueForDataSourceConfig	2020-05-22 04:53:41.173
696	/20200518035909-UseTupaiaAsDataServiceForLaosSchoolsSurveys	2020-05-22 04:53:43.205
697	/20200519020537-AddLaosSchoolsDormitoryMapOverlay	2020-05-22 04:53:43.376
698	/20200520071141-FixCaseInLaosSchoFixCaseInLaosSchoolsOverlays	2020-05-22 04:53:43.491
699	/20200520090416-UpdateMapOverlaysDormitorySchools	2020-05-22 04:53:43.52
700	/20200520112832-FixGroupingValuesInLaosSchoolsBinaryMeasuresOverlays	2020-05-22 04:53:43.716
701	/20200520223152-UpdateMapOverlaysDevPartners	2020-05-22 04:53:43.911
702	/20200521062959-AddIHRDashboardGroupToExplore	2020-05-22 04:53:44.003
703	/20200522020712-SetLaosSchoolsDefaultDashboardAndOverlay	2020-05-22 04:53:44.032
704	/20200514054511-AddBinaryShadedPolygonMeasuresLaosSchools	2020-05-22 06:36:37.011
705	/20200515021226-AddLaosSchoolShadedPolygonsForDropOutRatesDistrictLevel	2020-05-22 06:36:37.239
706	/20200517062602-AddLaosSchoolShadedPolygonsForRepetitionRatesDistrictLevel	2020-05-22 06:36:37.513
707	/20200518004335-AddLaosSchoolDashboardGroups	2020-05-22 06:36:37.763
708	/20200518020921-AddLaosSchoolsMaleFemalePieCharts	2020-05-22 06:36:38.023
709	/20200519074549-AddLaosSchoolShadedPolygonsForDropOutRatesProvinceLevel	2020-05-22 06:36:38.222
710	/20200519074621-AddLaosSchoolShadedPolygonsForRepetitionRatesProvinceLevel	2020-05-22 06:36:38.381
711	/20200520044744-AddDropoutAndRepeatRatesByGradeBarLaosSchools	2020-05-22 06:36:38.648
712	/20200520223705-AddLaosSchoolsLanguageOfStudentsPieChart	2020-05-22 06:36:38.777
713	/20200521034842-AddLaosSchoolBinaryDashbaord	2020-05-22 06:36:38.865
714	/20200521055848-RemoveUnwantedDataVisualizationsFromLaos	2020-05-22 06:36:39.074
715	/20200521215551-AddBCD1ToInternalDataFetch	2020-05-22 06:36:39.228
716	/20200521221711-FixLaosSchoolsBinaryMeasureMapOverlayNameTypo	2020-05-22 06:36:39.349
717	/20200521221800-UpdateLaosSchoolsPieChartsDataServices	2020-05-22 06:36:39.552
718	/20200522020600-FixNamesForLaosSchoolsOverlays	2020-05-22 06:36:39.714
719	/20200522031911-laosSchoolsFixUnicefCode	2020-05-22 06:36:39.753
720	/20200522032405-UpdateMapOverlayHeadings	2020-05-22 06:36:39.887
721	/20200522055413-ChangeLaosSchoolsOverlayGroupName	2020-05-22 06:36:39.921
722	/20200503063358-AddTongaDHIS2HealthCertificatesDistributedReport	2020-05-26 05:33:22.248
723	/20200508034036-UpdateDefaultTimePeriodFormatInDataBuilderConfig	2020-05-26 05:33:22.404
724	/20200522010341-updateLaosSchoolsBinaryDashboard	2020-05-26 05:33:22.531
725	/20200525044209-NoFunnyPeriods	2020-05-26 05:33:22.587
726	/20200526005827-RemoveWorldDashboardGroups	2020-05-26 05:33:22.618
727	/20200212052756-RemoveRedundantQuestionsWish	2020-05-28 07:05:49.153
728	/20200521005057-AddLaosDevelopmentPartnersReport	2020-05-28 07:05:49.46
729	/20200524231548-AddSchoolPercentDashboards	2020-05-28 07:05:50.058
730	/20200522022756-VisualisationsDefinedPerProject	2020-06-01 23:11:11.261
731	/20200524212939-LimitVisualisationsPerProject	2020-06-01 23:11:12.839
732	/20200528042309-DeleteAnswersForLaosSchoolsSelectVillageQuestions	2020-06-01 23:11:13.004
733	/20200521102324-AddUtilityServiceBinaryMeasuresBarCharts	2020-06-05 05:09:17.476
734	/20200521155232-AddResourceSupportBinaryMeasuresBarCharts	2020-06-05 05:09:17.765
735	/20200528011043-ChangeUNFPAReportsToUseQuarters	2020-06-05 05:09:17.857
736	/20200605045409-CorrectStriveDashboardCase	2020-06-05 05:09:17.912
737	/20200605051613-SetCovidDefaultDashboard	2020-06-11 22:06:48.088
738	/20200608220007-RenameQuestionIndicatorToName	2020-06-11 22:06:48.184
739	/20200608234924-RemoveLaosSchoolsReport	2020-06-11 22:06:48.527
740	/20200609022031-RemoveLaosSchoolsHeatmaps	2020-06-11 22:06:48.594
741	/20200609022859-UpdateOverlayHeadingsToRemoveTotal	2020-06-11 22:06:48.938
742	/20200612003644-AddMostVisualisationsToExplore	2020-06-12 01:09:53.702
743	/20200417211027-AllowNullAccessToken	2020-06-18 21:35:02.61
744	/20200422231733-MoveNoCountryUsersToAdminPanel	2020-06-18 21:35:02.717
745	/20200423213702-EntityBasedPermissions	2020-06-18 21:35:03.473
746	/20200525005457-WipeUserSessions	2020-06-18 21:35:03.546
747	/20200529000003-MigrateOverlaysToUseNewEntityAggregation	2020-06-18 21:35:05.868
748	/20200529064523-MoveMeasureLevelToPresentationOptions	2020-06-18 21:35:07.96
749	/20200601050232-MigrateReportsToUseNewEntityAggregation	2020-06-18 21:35:08.941
750	/20200602035743-FixConfigForSurveyExportReports	2020-06-18 21:35:11.342
751	/20200603012534-DeleteSurveyAndQuestionImageData	2020-06-18 21:35:11.364
752	/20200603012535-ChangeDuplicateSurveyCodes	2020-06-18 21:35:15.127
753	/20200603014358-AddUniqueCodeConstraintInSurvey	2020-06-18 21:35:15.193
754	/20200603032358-UseCountrySpecificBcdSurveys	2020-06-18 21:35:15.822
755	/20200609002315-UpdateSchoolBinaryListMeasures	2020-06-18 21:35:15.925
756	/20200609045707-UpdateLaosSchoolsBinaryMeasureMapOverlayNames	2020-06-18 21:35:16.046
757	/20200609045724-RemoveLaosSchoolsBinaryMeasureMapOverlays	2020-06-18 21:35:16.083
758	/20200609053914-UseTupaiaAsDataServiceForNewLaosSchoolSurveys	2020-06-18 21:35:18.666
759	/20200609055929-AddMoreLaosSchoolsBinaryMeasuresMapOverlays	2020-06-18 21:35:18.939
760	/20200609072253-AddLaosSchoolsStudentResourcesMapOverlays	2020-06-18 21:35:19.174
761	/20200609223042-AddWaterSupplyMapOverlay	2020-06-18 21:35:19.443
762	/20200612021300-FixIncorrectDashboardGroupProjects	2020-06-18 21:35:19.63
763	/20200616000806-FixIncorrectDataElementCodesLaosReport	2020-06-18 21:35:19.97
764	/20200617235154-FixTongaMeaslesOverlaysWithEntityAggregation	2020-06-18 21:35:20.008
765	/20200618090311-FixEntityAggregationConfig	2020-06-18 21:35:20.071
766	/20200603115106-AddCatchmentEntityType	2020-06-25 23:29:10.306
767	/20200615021108-AddLaosSchoolsMajorDevPartner	2020-06-25 23:29:11.339
768	/20200618012039-UseTuapaiaAsDataServiceForWishSurveys	2020-06-25 23:29:15.379
769	/20200528043308-createAccessRequestTable	2020-07-02 21:55:46.686
770	/20200603121401-CreateFijiCatchmentAlternateHierarchy	2020-07-02 21:55:54.593
771	/20200615045558-AddPopupHeaderFormatToLaosSchoolsOverlays	2020-07-02 21:55:54.946
772	/20200623065126-AddRegionalMapOverlaysForUNFPAMOS	2020-07-02 21:55:55.446
773	/20200625074843-AddMapOverlaysForRHServices	2020-07-02 21:55:55.695
774	/20200701064429-AddMethodsOfContraceptionRegionalDashboards	2020-07-02 21:55:55.794
775	/20200609034143-ChangeBinaryShadedPolygonsMeasuresLaosSchools	2020-07-09 22:25:52.91
776	/20200609045620-AddStriveReportToNationalLevel	2020-07-09 22:25:53.039
777	/20200617035342-AddCountryAndFacilityTongaHealthPromotionUnitDashboardGroups	2020-07-09 22:25:53.489
778	/20200617036620-AddActivitySessionsBySettingPieChartTonga	2020-07-09 22:25:53.753
779	/20200617045942-AddTongaDHIS2HPUPieChartNumberOfBroadcastsByTheme	2020-07-09 22:25:53.961
780	/20200617054710-AddActivitySessionsBySettingByDistrict	2020-07-09 22:25:54.214
781	/20200617071021-AddTongaHPUBarChartTotalPhysicalActivityParticipants	2020-07-09 22:25:54.33
782	/20200618014723-AddNewQuitlineCallsByYearTextReport	2020-07-09 22:25:54.465
783	/20200618131934-AddTongaHPUIECRequestsFulFilledByTargetGroupDashboardReport	2020-07-09 22:25:54.587
784	/20200618132339-AddTongaHPUIECRequestsFulFilledByThemeDashboardReport	2020-07-09 22:25:54.766
785	/20200619015233-AddNewQuitlineCasesBarReportTonga	2020-07-09 22:25:54.939
786	/20200623013336-AddTongaHPUNumberOfNCDRiskFactorScreeningEventsBySetting	2020-07-09 22:25:55.197
787	/20200624061918-AddUnfpaStackedBarGraphPercentCountryMos	2020-07-09 22:25:55.416
788	/20200624141424-AddUNFPAReproductiveHealthAtLeast1StaffMemberTrainedSRHServicesReport	2020-07-09 22:25:55.609
789	/20200626014357-AddUNFPAFacilityUseOfStockCardsMatrixReport	2020-07-09 22:25:55.765
790	/20200629134316-AddUNFPANumberOfWomenProvidedSRHServicesFacilityLevelDashboardReport	2020-07-09 22:25:55.895
791	/20200701000910-AddUNFPANumberOfWomenProvidedSRHServicesNationalProvincialLevelMatrix	2020-07-09 22:25:55.966
792	/20200502045201-AddFlutrackingParticipantsPerCapita	2020-07-16 21:41:43.261
793	/20200503031746-Add9FlutrackingOverlays	2020-07-16 21:41:44.48
794	/20200503043133-UpdateTongaHouseholdsToUseNeutralScale	2020-07-16 21:41:44.537
795	/20200510011141-AddFlutrackingOverlaysToLGALevel	2020-07-16 21:41:44.987
796	/20200521080146-AddLaosSchoolsBinaryMatrixDistrictLevelDashboard	2020-07-16 21:41:45.202
797	/20200601041635-HideUnncessarySurveysFromDemoLand	2020-07-16 21:41:45.42
798	/20200603043404-UpdateFlutrackingOverlaysToHaveAProject	2020-07-16 21:41:45.64
799	/20200609003258-AddLaosSchoolsRawDataDownloads	2020-07-16 21:41:45.829
800	/20200624001356-AddTongaCovid19CommodityAvailabilityRadiusMapNationalLevelOverlay	2020-07-16 21:41:46.063
801	/20200624043629-AddUNFPAPriorityLifeSavingMedicinesForWomenAndChildrenAMCMatrixReport	2020-07-16 21:41:46.186
802	/20200624090309-AddUNFPAPriorityLifeSavingMedicinesForWomenAndChildrenMOSMatrixReport	2020-07-16 21:41:46.411
803	/20200624090446-AddUNFPAPriorityLifeSavingMedicinesForWomenAndChildrenSOHMatrixReport	2020-07-16 21:41:46.611
804	/20200705044221-AddLaosSchoolsDistanceFromMainRoadMapOverlay	2020-07-16 21:41:46.906
805	/20200706011442-UpdateMultiBarBarChartPercentageOfUtilityAvailabilityOfSchoolsLaosSchools	2020-07-16 21:41:47.138
806	/20200706023151-UpdateMultiBarBarChartPercentageOfResourcesSupportReceivedOfSchoolsLaosSchools	2020-07-16 21:41:47.511
807	/20200706073546-UpdateMajorDevelopmentPartnerOverlayToDevelopmentPartnerSupportOverlay	2020-07-16 21:41:47.618
808	/20200710014909-FixFlutrackingOverlaysWithEntityAggregation-modifies-data	2020-07-16 21:41:47.934
809	/20200710081638-AddUNFPARepHealthProdMOSReportToProvinceLevel-modifies-data	2020-07-16 21:41:48.106
810	/20200710131831-AddRHOverlayToMsupplyCountries-modifies-data	2020-07-16 21:41:48.209
811	/20200712224256-ChangeDefaultCovidOverlayToStateTotalCases-modifies-data	2020-07-16 21:41:48.261
812	/20200713035339-FixVaccineReportReorderCells-modifies-data	2020-07-16 21:41:48.317
813	/20200715235459-AddGPSTagAndAbilityToAttachPhotoToLaosSchools-modifies-data	2020-07-16 21:41:48.452
814	/20200428025025-createAlertsTable	2020-07-23 23:00:35.162
815	/20200501033538-createCommentTables	2020-07-23 23:00:35.498
816	/20200617021631-AddUniqueConstraintInDataElementDataGroup	2020-07-23 23:00:35.98
817	/20200622025632-AddDataGroupsForAllSurveys	2020-07-23 23:00:37.449
818	/20200622025633-AddDataSourceIdColumn	2020-07-23 23:00:39.494
819	/20200622025634-RemoveDhis2InfoFromSurveyIntegrationMetadata	2020-07-23 23:00:39.805
820	/20200705042223-UpdateLaosSchoolsHandWashingFunctionalityMapOverlay	2020-07-23 23:00:40.11
821	/20200710031900-ChangDenominatorForSoughtMedicalAdviceFlutrackingOverlay-modifies-data	2020-07-23 23:00:40.165
822	/20200710065047-AddNewBinaryIndicatorTo5LaosSchoolsVisualisations-modifies-data	2020-07-23 23:00:40.519
823	/20200716001701-ChangeUnfpaStaffMatrixFacilityBaselineDate-modifies-data	2020-07-23 23:00:40.569
824	/20200625011337-AddUNFPARegionalLevelPercentageFacilitiesOfferingServicesDashboards	2020-07-28 22:33:32.881
825	/20200713235756-AddUnfpaRegionalLevelAtLest1StaffTrained-modifies-data	2020-07-28 22:33:33.259
826	/20200727002031-ChangeUNFPAProjectPermissionGroup-modifies-data	2020-07-28 22:33:33.291
827	/20200723044326-UpdateLaosSchoolsAccessToCleanWaterMapOverlay-modifies-data	2020-08-06 22:02:00.975
828	/20200724235329-MoveFrontEndMapOverlayInfoToPresentationOptionsColumn-modifies-data	2020-08-06 22:02:01.857
829	/20200724235629-DropFrontEndMapOverlayInfoColumns-modifies-schema	2020-08-06 22:02:02.07
830	/20200725050059-CreateMapOverlayGroupTables-modifies-schema	2020-08-06 22:02:02.225
831	/20200725050217-MigrateMapOverlayGroupData-modifies-data	2020-08-06 22:02:03.693
832	/20200725080640-DropMapOverlayGroupNameColumn-modifies-schema	2020-08-06 22:02:03.817
833	/20200726010801-CategoriseLaosSchoolsDropOutRatesMapOverlays-modifies-data	2020-08-06 22:02:04.263
834	/20200726031440-AddFluTrackingLandingPage-modifies-data	2020-08-06 22:02:04.3
835	/20200726083032-CategoriseLaosSchoolsRepetitionRatesMapOverlays-modifies-data	2020-08-06 22:02:04.61
836	/20200727071629-RemoveSchoolLevelBinaryIndicatorTable-modifies-data	2020-08-06 22:02:04.68
837	/20200804010531-ChangeStriveProjectDefaultMapOverlay-modifies-data	2020-08-06 22:02:04.721
838	/20200804021343-UpdateCOVIDAUProjectBackgroundUrl-modifies-data	2020-08-06 22:02:04.747
839	/20200617043305-AddWishCustomDataDownloadReport	2020-08-13 22:55:25.603
840	/20200623224901-RestrictWishRawDataDownloadAccess-modifies-data	2020-08-13 22:55:26.176
841	/20200710035752-AddUnfpaRawDataDownloadReproductiveHealthFacility-modifies-data	2020-08-13 22:55:26.379
842	/20200720095953-AddWishExportSurveyTestsByCode-modifies-data	2020-08-13 22:55:26.454
843	/20200723070535-AddLaosSchoolsPrimarySchoolLevelTextbookShortageByKeySubjectsAndGradesMatrix-modifies-data	2020-08-13 22:55:26.587
844	/20200726053205-AddLaosSchoolsLowerSecondarySchoolLevelTextbookShortageByKeySubjectsAndGradesMatrix-modifies-data	2020-08-13 22:55:26.84
845	/20200726053306-AddLaosSchoolsUpperSecondarySchoolLevelTextbookShortageByKeySubjectsAndGradesMatrix-modifies-data	2020-08-13 22:55:26.953
846	/20200727001331-AddLaosSchoolsPrimarySchoolLevelTextbookShortageBarGraph-modifies-data	2020-08-13 22:55:27.226
847	/20200727013315-AddLaosSchoolsLowerSecondarySchoolLevelTextbookShortageBarGraph-modifies-data	2020-08-13 22:55:27.579
848	/20200727013444-AddLaosSchoolsUpperSecondarySchoolLevelTextbookShortageBarGraph-modifies-data	2020-08-13 22:55:27.671
849	/20200730073820-AddLaosSchoolsMapOverlayPopulationDistrictAndProvinceLevel-modifies-data	2020-08-13 22:55:27.816
850	/20200803045941-AddUnfpaCountriesBackForSurveyRHFSC-modifies-data	2020-08-13 22:55:27.874
851	/20200803070231-AddLaosSchoolsFunctioningComputerOverlay-modifies-data	2020-08-13 22:55:28.004
852	/20200803233956-AddTongaHpuReportNutritionTotalSessionsConducted-modifies-data	2020-08-13 22:55:28.049
853	/20200804100254-AddReportTongaHpuHealthTalksSettingsTypePie-modifies-data	2020-08-13 22:55:28.126
854	/20200723055523-MigrateSpectrumScaleToNewFormat-modifies-data	2020-08-20 22:52:31.687
855	/20200723232942-FixFlutrackingOverlaysToHardLimitScale-modifies-data	2020-08-20 22:52:31.929
856	/20200729042609-AddLaosSchoolsTextbookToStudentRatioOverlay-modifies-data	2020-08-20 22:52:32.756
857	/20200803061954-RemoveLaosSchoolsStudentResourcesMapOverlays-modifies-data	2020-08-20 22:52:32.998
858	/20200803073517-AddNewLaosSchoolsElectricityAvailableOverlay-modifies-data	2020-08-20 22:52:33.19
859	/20200805072741-RemoveSomeLaosSchoolsSchoolIndicatorsEIEOverlays-modifies-data	2020-08-20 22:52:33.248
860	/20200805073136-UpdateLaosSchoolsOverlaysUsingSchCVD002-modifies-data	2020-08-20 22:52:33.301
861	/20200807115047-AddTongaHpuTobaccoWarningsFinesLocation-modifies-data	2020-08-20 22:52:33.427
862	/20200807061202-AddTotalScreenedForNCDRiskFactors-modifies-data	2020-08-27 22:13:12.29
863	/20200810005228-AddTongaHpuRateOfTobaccoNonComplianceDashboard-modifies-data	2020-08-27 22:13:12.399
864	/20200812034926-UpdateHP02NCDRiskFactorsScreeningEventsDashboard-modifies-data	2020-08-27 22:13:12.462
865	/20200814011117-FixUNFPAReportShowingOver100Percent-modifies-data	2020-08-27 22:13:12.724
935	/20201009061046-UpdateLaosEocEntities-modifies-data	2020-10-15 22:56:41.849
866	/20200814062713-DeprecateSpecificSumPerPeriodDatabuildersAndReplaceWithGeneric-modifies-data	2020-08-27 22:13:13.055
867	/20200817000740-AddTongaHpuReportNcdRiskFactorsByAgeAndGender-modifies-data	2020-08-27 22:13:13.183
868	/20200817045557-AddTongaHpuNumberOfInspectedAreasForTobaccoComplianceDashboard-modifies-data	2020-08-27 22:13:13.272
869	/20200817073430-ChangeFlutrackingOverlaysScaleBounds-modifies-data	2020-08-27 22:13:13.339
870	/20200820071030-FixIHRMapOverlaysMissingOrganisationUnitType-modifies-data	2020-08-27 22:13:13.404
871	/20200825113028-AddLaosEocProject-modifies-data	2020-08-27 22:13:13.673
872	/20200527025956-FixupsToMissingDataElementInPLSMDashboards	2020-09-03 23:25:54.617
873	/20200806062829-AddEmptyAndNoAccessDashboardReports-modifies-data	2020-09-03 23:25:55.75
874	/20200804082610-AddTongaHpuReportNutritionClientsByAgeGender-modifies-data	2020-09-10 22:49:47.74
875	/20200811090718-AddTongaHpuDashboardPieNumberNewQuitlineDistrict-modifies-data	2020-09-10 22:49:47.832
876	/20200831024802-UpdateUNFPAReportToAddFPData-modifies-data	2020-09-10 22:49:47.927
877	/20200903032810-AddStationProjectCodeAndProjectIdEntityTypes-modifies-schema	2020-09-10 22:49:54.539
878	/20200904032606-FixOldMeasureBuildersWithNewEntityAggregation-modifies-data	2020-09-10 22:49:54.79
879	/20200904053631-FixUnfpaRegionalTrainingData-modifies-data	2020-09-10 22:49:54.889
880	/20200909012517-AddParentToTongaPermissionGroup-modifies-data	2020-09-10 22:49:54.943
881	/20200805065956-DeleteSomeLaosSchoolsSchoolIndicatorsMapOverlays-modifies-data	2020-09-17 22:49:01.493
882	/20200805070112-CategoriseLaosSchoolsSchoolIndicatorsDistrictAndProvinceOverlays-modifies-data	2020-09-17 22:49:01.687
883	/20200805070208-AddOtherResponseToLaosSchoolsDevelopmentPartnerSupportOverlay-modifies-data	2020-09-17 22:49:01.945
884	/20200812043136-AddTongaHpuSettingTypeMapOverlay-modifies-data	2020-09-17 22:49:02.081
885	/20200828013343-AddMoreLaosSchoolsSchoolIndicatorsSubNationalLevelsMapOverlays-modifies-data	2020-09-17 22:49:02.558
886	/20200901150309-AddTongaHpuHealthTalksSettingTypeOverlay-modifies-data	2020-09-17 22:49:02.956
887	/20200901162829-AddTongaHpuPhysicalActivitySettingTypeOverlay-modifies-data	2020-09-17 22:49:03.14
888	/20200901175734-WishCustomSurveyExportSortByHouseholdId-modifies-data	2020-09-17 22:49:03.214
889	/20200910043451-AddCovidResultsToCD3bValidationReport-modifies-data	2020-09-17 22:49:03.269
890	/20200911061955-ClampLaosSchoolTextbookRatioOverlayScale-modifies-data	2020-09-17 22:49:03.335
891	/20200911065646-AddLaosSchoolsPolygonOverlaysStudentNumbers-modifies-data	2020-09-17 22:49:04.121
892	/20200921010041-FixLaosSchoolsSchoolIndicatorsEiESubNationalLevelsMapOverlaysEntityAggregation-modifies-data	2020-09-22 04:16:40.457
893	/20200720231712-AddIndicatorDataSourceType-modifies-schema	2020-09-25 00:25:59.955
894	/20200804033230-AddIndicatorTable-modifies-schema	2020-09-25 00:26:00.024
895	/20200826215112-UseAnalyticsPerPerPeriodBuilder-modifies-data	2020-09-25 00:26:00.186
896	/20200826215113-UseIndicatorsInStriveVisualisations-modifies-data	2020-09-25 00:26:01.41
897	/20200912130823-AddMoreLaosSchoolsSchoolIndicatorsEiEMapOverlays-modifies-data	2020-09-25 00:26:01.914
898	/20200914013333-UpdateLaosSchoolsSchoolIndicatorsEiEFunctioningTVMapOverlay-modifies-data	2020-09-25 00:26:02.098
899	/20200914013941-AddTextbookStudentRatioOverlaysDistrictAndProvinceLevel-modifies-data	2020-09-25 00:26:03.065
900	/20200914025424-UpdateLaosSchoolsSchoolIndicatorsEiEMapOverlaysWithMultipleValues-modifies-data	2020-09-25 00:26:03.314
901	/20200914043218-AddLaosSchoolsSchoolIndicatorsEiEDevelopmentPartnerSupportMapOverlayOtherResponse-modifies-data	2020-09-25 00:26:03.429
902	/20200914045259-RemoveSomeLaosSchoolsSchoolIndicatorsEiEMapOverlays-modifies-data	2020-09-25 00:26:03.502
903	/20200914080738-AddLaosSchoolsSchoolLevelICTFacilitiesDashboardReport-modifies-data	2020-09-25 00:26:03.564
904	/20200915040216-FixSamoaEntities-modifies-data	2020-09-25 00:26:04.348
905	/20200915054805-AddNcdReportsToCommunityHealthGroup-modifies-data	2020-09-25 00:26:04.413
906	/20200916061846-UpdateLaosSchoolsSchoolIndicatorsEiEFunctioningHandWashingFacilitiesMapOverlay-modifies-data	2020-09-25 00:26:04.475
907	/20200916082733-UpdateLaosSchoolsSchoolIndicatorsEiEUpdateAccessToWaterSupplyMapOverlay-modifies-data	2020-09-25 00:26:04.573
908	/20200920042029-AddLaosSchoolsPrePrimarySchoolLevelStudentNumbersTableDashboardReport-modifies-data	2020-09-25 00:26:04.611
909	/20200920055340-AddLaosSchoolsPrimarySchoolLevelStudentNumbersTableDashboardReport-modifies-data	2020-09-25 00:26:04.668
910	/20200920055441-AddLaosSchoolsSecondarySchoolLevelStudentNumbersTableDashboardReport-modifies-data	2020-09-25 00:26:04.722
911	/20200820022356-AddServiceTypeWeather-modifies-schema	2020-10-01 22:38:45.442
912	/20200910004911-AddWeatherDataElements-modifies-data	2020-10-01 22:38:46.733
913	/20200915004954-AddCovid19SchoolLevelReportLaos-modifies-data	2020-10-01 22:38:46.894
914	/20200916065711-AddWASHSchoolLevelReportLaos-modifies-data	2020-10-01 22:38:47.036
915	/20200917071431-AddTeachingAndLearningSchoolLevelDashboardLaos-modifies-data	2020-10-01 22:38:47.114
916	/20200925004629-AddSchoolDetailsTablesLaosSchools-modifies-data	2020-10-08 23:03:48.147
917	/20200926083458-CreateLaosSchoolsICTFacilitiesBarGraphDashboardReport-modifies-data	2020-10-08 23:03:48.303
918	/20200928022356-AddEntityTypeCity-modifies-schema	2020-10-08 23:03:52.994
919	/20200928061046-AddLaosEocEntities-modifies-data	2020-10-08 23:03:58.193
920	/20200928061654-CreateLaosSchoolsCOVID19BarGraphDashboardReport-modifies-data	2020-10-08 23:03:58.32
921	/20200928063927-CreateLaosSchoolsWASHBarGraphDashboardReport-modifies-data	2020-10-08 23:03:58.468
922	/20200928065206-CreateLaosSchoolsTeachingAndLearningBarGraphDashboardReport-modifies-data	2020-10-08 23:03:58.637
923	/20200910024211-CreateNewCovidDashboardSamoa-modifies-data	2020-10-15 22:56:34.161
924	/20200923065724-ConvertOverlaySortOrderToInteger-modifies-data	2020-10-15 22:56:34.266
925	/20200924001437-AddSortOrderToMapOverlayGroupRelationTable-modifies-schema	2020-10-15 22:56:34.317
926	/20200924001940-MigrateSortOrderDataFromMapOverlayTableToMapOverlayGroupRelationTable-modifies-data	2020-10-15 22:56:34.837
927	/20200924004521-DropSortOrderColumnFromMapOverlayTable-modifies-schema	2020-10-15 22:56:34.937
928	/20200924035244-DeleteOrphanMapOverlayRelations-modifies-data	2020-10-15 22:56:34.987
929	/20200925011104-CreateRootMapOverlay-modifies-data	2020-10-15 22:56:35.026
930	/20200925012948-ConnectTopLevelMapOverlayGroupsToWorldMapOverlayGroup-modifies-data	2020-10-15 22:56:35.176
931	/20200925051137-ReorderLaosSchoolsSchoolIndicatorsMapOverlays-modifies-data	2020-10-15 22:56:35.414
932	/20200925064855-ReorderLaosSchoolsOverlayGroups-modifies-data	2020-10-15 22:56:35.512
933	/20200929223403-AddTileSetsToProject-modifies-schema	2020-10-15 22:56:35.556
934	/20201002022840-AddProfileImageToUserAccount-modifies-schema	2020-10-15 22:56:35.594
936	/20201015015257-DeleteAnswerWith9998-modifies-data	2020-10-15 22:56:42.781
937	/20201019011335-RemoveRedundantDataInFijiEntity-modifies-data	2020-10-22 21:05:09.326
938	/20201026223059-UpdateLinkOnFeedItems-modifies-data	2020-10-29 21:35:21.235
939	/20200925020630-AddStackedBarGraphsBySchoolTypeLaosSchools-modifies-data	2020-11-06 00:18:41.417
940	/20200930141002-AddLaosSchoolsNumberOfSchoolsSupportedByDevelopmentPartnersDashboardReport-modifies-data	2020-11-06 00:18:41.935
941	/20201002053523-AddDistrictDetailsTablesLaosSchools-modifies-data	2020-11-06 00:18:42.139
942	/20201005040334-AddProvinceAndNationalDetailsTablesLaosSchools-modifies-data	2020-11-06 00:18:42.27
943	/20201008065400-AddLaosSchoolsNumberOfStudentsMatrix-modifies-data	2020-11-06 00:18:42.337
944	/20201021060652-AddAttributesColumnIntoOptionTable-modifies-schema	2020-11-06 00:18:42.494
945	/20201103092344-AddPSSSProject-modifies-data	2020-11-06 00:18:42.916
946	/20200824014037-CreateEntityHierarchyCache-modifies-schema	2020-11-13 00:26:44.1
947	/20201002193222-AddEntityParentIdIndex-modifies-schema	2020-11-13 00:26:44.561
948	/20201006211507-BuildAncestorDescendantRelationCache-modifies-data	2020-11-13 00:27:45.26
949	/20201008205444-IncludeOldRecordInChangeNotifications-modifies-schema	2020-11-13 00:27:45.304
950	/20201009035426-AddImmutableTableTrigger-modifies-schema	2020-11-13 00:27:45.324
951	/20201026232410-DeleteEntityPublicHealthService-modifies-data	2020-11-13 00:27:46.03
952	/20201105014950-AddEntityTypesToHierarchy-modifies-schema	2020-11-13 00:27:46.077
953	/20201105015339-AddCasesAsCanonicalInSomeHierarchies-modifies-data	2020-11-13 00:27:46.098
954	/20201110210258-AddFijiDistrictsToEntityRelation-modifies-data	2020-11-13 00:27:46.161
955	/20201006024935-AddLaosSchoolsTextbookStudentRatioBarGraph-modifies-data	2020-11-19 23:41:00.749
956	/20201110234830-DeleteOldLaosSchoolsTextbookData-modifies-data	2020-11-19 23:41:09.874
957	/20201116002004-ChangeUNFPADefaultMeasure-modifies-data	2020-11-19 23:41:09.903
958	/20201117025041-DeleteTestDistrictEntity-modifies-data	2020-11-19 23:41:10.278
959	/20201008010413-AddLaosEocHistoricMapOverlays-modifies-data	2020-11-27 00:20:09.645
960	/20201009010413-AddLaosEocForecastMapOverlays-modifies-data	2020-11-27 00:20:09.986
961	/20201012010424-AddLaosEocWeatherDashboards-modifies-data	2020-11-27 00:20:10.128
962	/20201014220808-AddLaosEocAggregateForecastMapOverlays-modifies-data	2020-11-27 00:20:10.254
963	/20201028234713-AddReportsTable-modifies-schema	2020-11-27 00:20:10.322
964	/20201104032225-AddDashboardGroupForMS1Administration-modifies-data	2020-11-27 00:20:10.383
965	/20201123002611-AddNZToPSSSProject-modifies-data	2020-11-27 00:20:10.46
966	/20201123061122-AddConfirmedWeeklyDataReportForPSSS-modifies-data	2020-11-27 00:20:10.503
967	/20201124054820-AddPsssSessionTable-modifies-schema	2020-11-27 00:20:10.523
968	/20201117053359-AddPsssWoWIncreaseIndicators-modifies-data	2020-12-04 01:26:07.217
969	/20201118022314-ChangePeriodGraularityInUnfpaPriorityMedicinesMatrixDashboardReport-modifies-data	2020-12-04 01:26:07.743
970	/20201118220905-ReorderRowsToMosAmcSohTablesForUnfpa-modifies-data	2020-12-04 01:26:08.149
971	/20201125021221-AddPsssAlertThresholdIndicators-modifies-data	2020-12-04 01:26:09.126
972	/20201125204230-removeToDeliveryServiceStockReport-modifies-data	2020-12-04 01:26:09.32
973	/20201126060032-AddUnconfirmedWeeklyDataReportForPSSS-modifies-data	2020-12-04 01:26:09.581
974	/20201129051349-DropPSSSSessionNotifyChangesTrigger-modifies-schema	2020-12-04 01:26:09.631
975	/20201201022321-AddPSSSTotalSitesIndicator-modifies-data	2020-12-04 01:26:09.866
976	/20201201033216-AddProjectCovid19Samoa-modifies-data	2020-12-04 01:26:10.165
977	/20201111013312-RemoveItemsFromLineChartsInUnfpaDashboard-modifies-data	2020-12-11 02:55:22.949
978	/20201116013159-AddMinMaxValuestoMOSReport-modifies-data	2020-12-11 02:55:22.998
979	/20201116024506-RemoveMapOverlayUNFPA-modifies-data	2020-12-11 02:55:23.088
980	/20201120051651-RemoveItemsFromMapOverLayGroupsRelationInUnfpa-modifies-data	2020-12-11 02:55:23.289
981	/20201120051938-DeleteItemsInUnfpaStockMosByPercentCountries-modifies-data	2020-12-11 02:55:23.402
982	/20201120052316-DeleteItemsFromUnfpaPriorityMedicinesTable-modifies-data	2020-12-11 02:55:23.596
983	/20201208010502-AddPSSSWeekyCasesReport-modifies-data	2020-12-11 02:55:23.703
984	/20201208234222-SplitLaosSchoolsDashboardGroups-modifies-data	2020-12-11 02:55:23.929
985	/20201209001056-ChangePSSSReportsToUseLastPerPeriodPerOrgUnit-modifies-data	2020-12-11 02:55:23.997
986	/20201209052048-EditWoWIndicatorsToGiveRelativeIncrease-modifies-data	2020-12-11 02:55:24.067
987	/20201209232802-EditSiteAverageIndicatorsToSupportDivByZero-modifies-data	2020-12-11 02:55:24.397
988	/20201213223856-AddCanonicalTypesToSamoaCovid-modifies-data	2020-12-17 02:16:55.857
989	/20201214000845-ChangeDotMatrixViewSchema-modifies-data	2020-12-17 02:16:56.08
990	/20201214000945-AddLegendsToUNFPAMatricies-modifies-data	2020-12-17 02:16:56.19
991	/20201215080555-UpdateFormulaAndDefaultValuesForPreviousWeeksToAlertThresholdLevelIndicators-modifies-data	2020-12-17 02:16:56.27
992	/20201126030925-AddPngRawDataDownloadSurveyPermissions-modifies-data	2021-01-07 23:09:19.224
993	/20201201082830-AddProjectPalauOlangch-modifies-data	2021-01-07 23:09:19.466
994	/20201208103439-AddPalauEntities-modifies-data	2021-01-07 23:09:20.319
995	/20201213223857-AddTotalRepatriatedPassengersCovid19ReportSoamoa-modifies-data	2021-01-07 23:09:20.421
996	/20201214092416-LaosSchoolsAddMoesGroup-modifies-data	2021-01-07 23:09:20.445
997	/20210105024922-AddDateSeletorHpu-modifies-data	2021-01-07 23:09:20.603
998	/20210107010710-AddPgToDiaSurveyCountryIds-modifies-data	2021-01-07 23:09:20.674
999	/20210107015502-SamoaUseBcdsSurveyForRawDataDownload-modifies-data	2021-01-07 23:09:20.71
1000	/20201216050328-AddCovidSamoaAgeByFlightMatrix-modifies-data	2021-01-14 22:37:18.017
1001	/20201220233030-ConvertAlertsToSurveyResponses-modifies-schema	2021-01-14 22:37:18.092
1002	/20210120051444-ResyncSubmissionsAfterRelease70-modifies-data	2021-01-21 04:35:14.832
1003	/20210106000258-HeatmapOfVillageConfirmedAndSuspectedCases-modifies-data	2021-01-21 21:32:43.153
1004	/20210110220114-AddCovidSamoaDemoIndivQuarhealthCond-modifies-data	2021-01-21 21:32:43.253
1005	/20210114103503-AddCovidSamoaDemoIndivQuarSex-modifies-data	2021-01-21 21:32:43.315
1006	/20210114125216-AddCovidSamoaClearanceDocuments-modifies-data	2021-01-21 21:32:43.368
1007	/20210118014114-CreateIndividualEntityType-modifies-schema	2021-01-21 21:32:45.157
1008	/20210118040638-AddFetpProject-modifies-data	2021-01-21 21:32:45.3
1009	/20210125010541-ResyncDelayedSubmissionsAfterRelease70-modifies-data	2021-01-27 05:47:35.825
1010	/20201117224102-DeleteUNFPAStaffTrainedLines-modifies-data	2021-01-28 22:30:09.496
1011	/20201117224832-AddUNFPAStaffTrainedMatrix-modifies-data	2021-01-28 22:30:09.568
1012	/20201123014943-IntegrateInconsistentAnswersForHotelNames-modifies-data	2021-01-28 22:30:10.729
1013	/20201204224102-DeleteUNFPAStaffTrainedLinesCountry-modifies-data	2021-01-28 22:30:10.823
1014	/20201204224832-AddUNFPAStaffTrainedMatrixCountry-modifies-data	2021-01-28 22:30:11.098
1015	/20210114131303-AddCovidSamoaQuarantineSiteByFlight-modifies-data	2021-01-28 22:30:11.186
1016	/20210121213045-MigrateStriveCanonicalToAlternateHeirarchy-modifies-data	2021-01-28 22:30:11.443
1017	/20210125033426-MigrateFijiSurveyDataElementsFromDHISToTupaia-modifies-data	2021-01-28 22:30:11.923
1018	/20210107004358-AddSwapColorForLegendInLaoSchool-modifies-data	2021-02-04 22:20:14.056
1019	/20210125051145-AddGeneralDashboardToPalau-modifies-data	2021-02-04 22:20:14.143
1020	/20210125061447-AddK13PCRResultsBarGraph-modifies-data	2021-02-04 22:20:14.247
1021	/20210126013657-AddK13C580YPositiveMapOverlay-modifies-data	2021-02-04 22:20:14.457
1022	/20210129022440-AddFacilityTypeOverlayForFiji-modifies-data	2021-02-04 22:20:14.611
1023	/20210201230429-MoveServiceTypeOverlayGroupToTheTop-modifies-data	2021-02-04 22:20:14.686
1024	/20210125025423-ChangePermissionInSamoaToCovid19Senior-modifies-data	2021-02-12 00:34:03.53
1025	/20210125042225-SamoaCovidSurveyHierarchyUpdate-modifies-data	2021-02-12 00:34:07.715
1026	/20210126234710-HeatmapHomeVillageOfQuarantinePassengers-modifies-data	2021-02-12 00:34:07.932
1027	/20210127010108-AddMissingDataElements-modifies-data	2021-02-12 00:34:45.786
1028	/20210127064624-MedicalCertificateLegendColorChange-modifies-data	2021-02-12 00:34:46.507
1029	/20210128033137-AddSurveyDateElementsForDhisSurveys-modifies-data	2021-02-12 00:34:56.045
1030	/20210128033138-AddPreaggregatedDataElements-modifies-data	2021-02-12 00:34:56.843
1031	/20210128033139-AddMissingDataElementDataGroups-modifies-data	2021-02-12 00:35:24.249
1032	/20210201040026-AddDataSourceIdNotNullConstraints-modifies-schema	2021-02-12 00:35:24.489
1033	/20210202053553-AddIndividualToFetpCanonicalTypes-modifies-data	2021-02-12 00:35:24.623
1034	/20210202204715-AddPalauDashboardGroupSupplyChain-modifies-data	2021-02-12 00:35:24.687
1035	/20210209030539-AddMissingDataGroups-modifies-data	2021-02-12 00:35:24.947
1036	/20210119053017-SomoaCovidCustomisedRawDataDownload-modifies-data	2021-02-18 22:21:40.842
1037	/20210202061216-AddFetpGraduateIndividualProfiles-modifies-data	2021-02-18 22:21:40.991
1038	/20210204025332-CreateFetpDashboardGroupsForProvDistrict-modifies-data	2021-02-18 22:21:41.08
1039	/20210204211247-AddFetpDashboardGraduatesBySex-modifies-data	2021-02-18 22:21:41.123
1040	/20210207040642-AddFETPActiveGraduatesMapOverlays-modifies-data	2021-02-18 22:21:41.308
1041	/20210208025858-RemoveSurveyFromRawDataDownload-modifies-data	2021-02-18 22:21:41.372
1042	/20210209005053-RenameCaseEntityToIndividualEntity-modifies-data	2021-02-18 22:21:42.216
1043	/20210209044534-MapOverlayAndDashboardToSupportIndividualFromCase-modifies-data	2021-02-18 22:21:42.596
1044	/20210210031149-SamoaRawDataDownloadDashboardGroup-modifies-data	2021-02-18 22:21:42.793
1045	/20210211025858-UpdateFETPGraduateProfileReports-modifies-data	2021-02-18 22:21:42.916
1046	/20210123065802-MigrateRadioQuestionsToBinaryQuestionsInLaosSchools-modifies-data	2021-02-25 23:10:49.214
1047	/20210123071051-MigrateLaosSchoolsDashboardsBinaryDataToZeroOne-modifies-data	2021-02-25 23:10:49.343
1048	/20210123120226-MigrateLaosSchoolsMapOverlaysBinaryDataToZeroOne-modifies-data	2021-02-25 23:10:49.81
1049	/20210124013906-FixLaosSchoolsDevelopmentPartnerSupportMapOverlay-modifies-data	2021-02-25 23:10:49.911
1050	/20210124014513-UpdateLaosSchoolsDevPartnersMapOverlays-modifies-data	2021-02-25 23:10:50.003
1051	/20210124020024-UpdateLaosSchoolsSpecialMapOverlays-modifies-data	2021-02-25 23:10:50.269
1052	/20210124055714-ConvertDhisSurveysIntoTupaia-modifies-data	2021-02-25 23:10:51.767
1053	/20210124063304-ConvertSurveyRawDataDownloadToCustomDataDownload-modifies-data	2021-02-25 23:10:51.858
1054	/20210124073946-FixUNFPAPercentagesOfFacilitiesOfferingServicesReports-modifies-data	2021-02-25 23:10:52.071
1055	/20210124115954-FixUNFPAContraceptivesOfferedReport-modifies-data	2021-02-25 23:10:52.164
1056	/20210128102520-PalauFacilityOpeningHoursDashboard-modifies-data	2021-02-25 23:10:52.297
1057	/20210202031622-NutritionCounsellingTotalNewAndExistingClients-modifies-data	2021-02-25 23:10:52.508
1058	/20210205033535-AddSTRIVEMolecularDataOverlays-modifies-data	2021-02-25 23:10:52.708
1059	/20210216014736-UpdateCountryCodeForIndividuals-modifies-data	2021-02-25 23:10:52.88
1060	/20210216073210-AddFetpDashboardGradByDistrict-modifies-data	2021-02-25 23:10:53.005
1061	/20210217053158-ChangeElementsServiceTypeToTupaia-modifies-data	2021-02-25 23:10:53.098
1062	/20210224014424-AddConfigToProjects-modifies-schema	2021-02-25 23:10:53.351
1063	/20201203010928-StockStatusForNonMsupplyContriesInFacilityLevel-modifies-data	2021-03-04 15:09:15.631
1064	/20210211051517-RenameArithmeticIndicators-modifies-data	2021-03-04 15:09:15.832
1065	/20210216015237-AddWeatherSourceToDashboardTitle-modifies-data	2021-03-04 15:09:16.349
1066	/20210223002537-AddReferenceToMapOverlays-modifies-data	2021-03-04 15:09:16.567
1067	/20210225033329-RemoveLaosOxygenConcentratorsProject-modifies-data	2021-03-04 15:09:35.867
1068	/20210301123426-AddFetpDashboardsToSolomonIs-modifies-data	2021-03-04 15:09:35.974
1069	/20210303020040-removeStriveMapOverlaysFromExplore-modifies-data	2021-03-04 15:09:36.101
\.


--
-- Name: migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.migrations_id_seq', 1069, true);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

