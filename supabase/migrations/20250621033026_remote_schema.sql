

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."get_active_fcm_tokens"("p_user_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_notification_type" "text" DEFAULT NULL::"text") RETURNS TABLE("user_id" "uuid", "fcm_token" "text", "device_type" "text", "notification_enabled" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ud.user_id,
    ud.fcm_token,
    ud.device_type,
    (up.push_notifications_enabled AND ud.push_enabled AND 
     CASE 
       WHEN p_notification_type IS NOT NULL THEN 
         COALESCE((up.notification_preferences->>p_notification_type)::boolean, true)
       ELSE true
     END) as notification_enabled
  FROM public.user_devices ud
  JOIN public.user_profiles up ON ud.user_id = up.id
  WHERE 
    ud.fcm_token IS NOT NULL
    AND (p_user_ids IS NULL OR ud.user_id = ANY(p_user_ids))
    AND ud.last_active_at > NOW() - INTERVAL '30 days' -- 30일 이내 활성 사용자
  ORDER BY ud.last_active_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_active_fcm_tokens"("p_user_ids" "uuid"[], "p_notification_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  INSERT INTO public.user_profiles (
    id,
    email,
    full_name,
    avatar_url,
    google_id,
    provider,
    last_sign_in_at
  )
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'avatar_url',
    NEW.raw_user_meta_data->>'sub', -- Google ID
    COALESCE(NEW.raw_app_meta_data->>'provider', 'google'),
    NEW.last_sign_in_at
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    full_name = EXCLUDED.full_name,
    avatar_url = EXCLUDED.avatar_url,
    last_sign_in_at = EXCLUDED.last_sign_in_at,
    updated_at = NOW();
    
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_fcm_token"("p_device_id" "text", "p_fcm_token" "text", "p_device_type" "text" DEFAULT 'android'::"text", "p_device_name" "text" DEFAULT NULL::"text", "p_os_version" "text" DEFAULT NULL::"text", "p_app_version" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
  v_device_record_id UUID;
BEGIN
  -- 현재 사용자 ID 가져오기
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  -- 기존 디바이스 업데이트 또는 새 디바이스 삽입
  INSERT INTO public.user_devices (
    user_id,
    device_id,
    fcm_token,
    device_type,
    device_name,
    os_version,
    app_version,
    last_active_at
  )
  VALUES (
    v_user_id,
    p_device_id,
    p_fcm_token,
    p_device_type,
    p_device_name,
    p_os_version,
    p_app_version,
    NOW()
  )
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    fcm_token = EXCLUDED.fcm_token,
    device_type = EXCLUDED.device_type,
    device_name = COALESCE(EXCLUDED.device_name, user_devices.device_name),
    os_version = COALESCE(EXCLUDED.os_version, user_devices.os_version),
    app_version = COALESCE(EXCLUDED.app_version, user_devices.app_version),
    last_active_at = EXCLUDED.last_active_at,
    updated_at = NOW()
  RETURNING id INTO v_device_record_id;
  
  -- user_profiles의 fcm_token도 업데이트 (기본 토큰으로 사용)
  UPDATE public.user_profiles 
  SET 
    fcm_token = p_fcm_token,
    last_active_at = NOW(),
    updated_at = NOW()
  WHERE id = v_user_id;
  
  RETURN v_device_record_id;
END;
$$;


ALTER FUNCTION "public"."update_fcm_token"("p_device_id" "text", "p_fcm_token" "text", "p_device_type" "text", "p_device_name" "text", "p_os_version" "text", "p_app_version" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_notification_preferences"("p_preferences" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  
  UPDATE public.user_profiles 
  SET 
    notification_preferences = p_preferences,
    updated_at = NOW()
  WHERE id = v_user_id;
  
  RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."update_notification_preferences"("p_preferences" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."fcm_notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "notification_type" "text" NOT NULL,
    "data" "jsonb" DEFAULT '{}'::"jsonb",
    "fcm_token" "text" NOT NULL,
    "fcm_message_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."fcm_notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "device_id" "text" NOT NULL,
    "fcm_token" "text" NOT NULL,
    "device_type" "text" NOT NULL,
    "device_name" "text",
    "os_version" "text",
    "app_version" "text",
    "push_enabled" boolean DEFAULT true,
    "last_active_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "user_devices_device_type_check" CHECK (("device_type" = ANY (ARRAY['android'::"text", 'ios'::"text", 'web'::"text"])))
);


ALTER TABLE "public"."user_devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_profiles" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "full_name" "text",
    "avatar_url" "text",
    "google_id" "text",
    "provider" "text" DEFAULT 'google'::"text",
    "fcm_token" "text",
    "push_notifications_enabled" boolean DEFAULT true,
    "notification_preferences" "jsonb" DEFAULT '{"chat": true, "updates": true, "marketing": true, "reminders": true}'::"jsonb",
    "device_info" "jsonb" DEFAULT '{}'::"jsonb",
    "last_sign_in_at" timestamp with time zone,
    "last_active_at" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_profiles" OWNER TO "postgres";


ALTER TABLE ONLY "public"."fcm_notifications"
    ADD CONSTRAINT "push_notification_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_fcm_token_key" UNIQUE ("fcm_token");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_user_id_device_id_key" UNIQUE ("user_id", "device_id");



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_google_id_key" UNIQUE ("google_id");



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_push_logs_created_at" ON "public"."fcm_notifications" USING "btree" ("created_at");



CREATE INDEX "idx_push_logs_type" ON "public"."fcm_notifications" USING "btree" ("notification_type");



CREATE INDEX "idx_push_logs_user_id" ON "public"."fcm_notifications" USING "btree" ("user_id");



CREATE INDEX "idx_user_devices_device_id" ON "public"."user_devices" USING "btree" ("device_id");



CREATE INDEX "idx_user_devices_fcm_token" ON "public"."user_devices" USING "btree" ("fcm_token");



CREATE INDEX "idx_user_devices_last_active" ON "public"."user_devices" USING "btree" ("last_active_at");



CREATE INDEX "idx_user_devices_user_id" ON "public"."user_devices" USING "btree" ("user_id");



CREATE INDEX "idx_user_profiles_email" ON "public"."user_profiles" USING "btree" ("email");



CREATE INDEX "idx_user_profiles_fcm_token" ON "public"."user_profiles" USING "btree" ("fcm_token");



CREATE INDEX "idx_user_profiles_google_id" ON "public"."user_profiles" USING "btree" ("google_id");



CREATE INDEX "idx_user_profiles_last_active" ON "public"."user_profiles" USING "btree" ("last_active_at");



CREATE OR REPLACE TRIGGER "handle_user_devices_updated_at" BEFORE UPDATE ON "public"."user_devices" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "handle_user_profiles_updated_at" BEFORE UPDATE ON "public"."user_profiles" FOR EACH ROW EXECUTE FUNCTION "public"."handle_updated_at"();



CREATE OR REPLACE TRIGGER "push_hook" AFTER INSERT ON "public"."fcm_notifications" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://etzdjyacuttprzswjbfp.supabase.co/functions/v1/push', 'POST', '{"Content-type":"application/json"}', '{}', '1000');



ALTER TABLE ONLY "public"."fcm_notifications"
    ADD CONSTRAINT "push_notification_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."user_profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_profiles"
    ADD CONSTRAINT "user_profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Service role can manage notification logs" ON "public"."fcm_notifications" USING (("auth"."role"() = 'service_role'::"text"));



CREATE POLICY "Users can insert own profile" ON "public"."user_profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can manage own devices" ON "public"."user_devices" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."user_profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



CREATE POLICY "Users can view own notification logs" ON "public"."fcm_notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own profile" ON "public"."user_profiles" FOR SELECT USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."fcm_notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_devices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."user_profiles" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."get_active_fcm_tokens"("p_user_ids" "uuid"[], "p_notification_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_active_fcm_tokens"("p_user_ids" "uuid"[], "p_notification_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_active_fcm_tokens"("p_user_ids" "uuid"[], "p_notification_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_fcm_token"("p_device_id" "text", "p_fcm_token" "text", "p_device_type" "text", "p_device_name" "text", "p_os_version" "text", "p_app_version" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."update_fcm_token"("p_device_id" "text", "p_fcm_token" "text", "p_device_type" "text", "p_device_name" "text", "p_os_version" "text", "p_app_version" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_fcm_token"("p_device_id" "text", "p_fcm_token" "text", "p_device_type" "text", "p_device_name" "text", "p_os_version" "text", "p_app_version" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_notification_preferences"("p_preferences" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."update_notification_preferences"("p_preferences" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_notification_preferences"("p_preferences" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";


















GRANT ALL ON TABLE "public"."fcm_notifications" TO "anon";
GRANT ALL ON TABLE "public"."fcm_notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."fcm_notifications" TO "service_role";



GRANT ALL ON TABLE "public"."user_devices" TO "anon";
GRANT ALL ON TABLE "public"."user_devices" TO "authenticated";
GRANT ALL ON TABLE "public"."user_devices" TO "service_role";



GRANT ALL ON TABLE "public"."user_profiles" TO "anon";
GRANT ALL ON TABLE "public"."user_profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."user_profiles" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
