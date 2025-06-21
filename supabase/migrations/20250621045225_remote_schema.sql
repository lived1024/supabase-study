drop trigger if exists "push_hook" on "public"."fcm_notifications";

drop trigger if exists "handle_user_devices_updated_at" on "public"."user_devices";

drop trigger if exists "handle_user_profiles_updated_at" on "public"."user_profiles";

drop policy "Service role can manage notification logs" on "public"."fcm_notifications";

drop policy "Users can view own notification logs" on "public"."fcm_notifications";

drop policy "Users can manage own devices" on "public"."user_devices";

drop policy "Users can insert own profile" on "public"."user_profiles";

drop policy "Users can update own profile" on "public"."user_profiles";

drop policy "Users can view own profile" on "public"."user_profiles";

revoke delete on table "public"."user_devices" from "anon";

revoke insert on table "public"."user_devices" from "anon";

revoke references on table "public"."user_devices" from "anon";

revoke select on table "public"."user_devices" from "anon";

revoke trigger on table "public"."user_devices" from "anon";

revoke truncate on table "public"."user_devices" from "anon";

revoke update on table "public"."user_devices" from "anon";

revoke delete on table "public"."user_devices" from "authenticated";

revoke insert on table "public"."user_devices" from "authenticated";

revoke references on table "public"."user_devices" from "authenticated";

revoke select on table "public"."user_devices" from "authenticated";

revoke trigger on table "public"."user_devices" from "authenticated";

revoke truncate on table "public"."user_devices" from "authenticated";

revoke update on table "public"."user_devices" from "authenticated";

revoke delete on table "public"."user_devices" from "service_role";

revoke insert on table "public"."user_devices" from "service_role";

revoke references on table "public"."user_devices" from "service_role";

revoke select on table "public"."user_devices" from "service_role";

revoke trigger on table "public"."user_devices" from "service_role";

revoke truncate on table "public"."user_devices" from "service_role";

revoke update on table "public"."user_devices" from "service_role";

revoke delete on table "public"."user_profiles" from "anon";

revoke insert on table "public"."user_profiles" from "anon";

revoke references on table "public"."user_profiles" from "anon";

revoke select on table "public"."user_profiles" from "anon";

revoke trigger on table "public"."user_profiles" from "anon";

revoke truncate on table "public"."user_profiles" from "anon";

revoke update on table "public"."user_profiles" from "anon";

revoke delete on table "public"."user_profiles" from "authenticated";

revoke insert on table "public"."user_profiles" from "authenticated";

revoke references on table "public"."user_profiles" from "authenticated";

revoke select on table "public"."user_profiles" from "authenticated";

revoke trigger on table "public"."user_profiles" from "authenticated";

revoke truncate on table "public"."user_profiles" from "authenticated";

revoke update on table "public"."user_profiles" from "authenticated";

revoke delete on table "public"."user_profiles" from "service_role";

revoke insert on table "public"."user_profiles" from "service_role";

revoke references on table "public"."user_profiles" from "service_role";

revoke select on table "public"."user_profiles" from "service_role";

revoke trigger on table "public"."user_profiles" from "service_role";

revoke truncate on table "public"."user_profiles" from "service_role";

revoke update on table "public"."user_profiles" from "service_role";

alter table "public"."fcm_notifications" drop constraint "push_notification_logs_user_id_fkey";

alter table "public"."user_devices" drop constraint "user_devices_device_type_check";

alter table "public"."user_devices" drop constraint "user_devices_fcm_token_key";

alter table "public"."user_devices" drop constraint "user_devices_user_id_device_id_key";

alter table "public"."user_devices" drop constraint "user_devices_user_id_fkey";

alter table "public"."user_profiles" drop constraint "user_profiles_email_key";

alter table "public"."user_profiles" drop constraint "user_profiles_google_id_key";

alter table "public"."user_profiles" drop constraint "user_profiles_id_fkey";

alter table "public"."fcm_notifications" drop constraint "push_notification_logs_pkey";

alter table "public"."user_devices" drop constraint "user_devices_pkey";

alter table "public"."user_profiles" drop constraint "user_profiles_pkey";

drop index if exists "public"."idx_push_logs_created_at";

drop index if exists "public"."idx_push_logs_type";

drop index if exists "public"."idx_push_logs_user_id";

drop index if exists "public"."idx_user_devices_device_id";

drop index if exists "public"."idx_user_devices_fcm_token";

drop index if exists "public"."idx_user_devices_last_active";

drop index if exists "public"."idx_user_devices_user_id";

drop index if exists "public"."idx_user_profiles_email";

drop index if exists "public"."idx_user_profiles_fcm_token";

drop index if exists "public"."idx_user_profiles_google_id";

drop index if exists "public"."idx_user_profiles_last_active";

drop index if exists "public"."push_notification_logs_pkey";

drop index if exists "public"."user_devices_fcm_token_key";

drop index if exists "public"."user_devices_pkey";

drop index if exists "public"."user_devices_user_id_device_id_key";

drop index if exists "public"."user_profiles_email_key";

drop index if exists "public"."user_profiles_google_id_key";

drop index if exists "public"."user_profiles_pkey";

drop table "public"."user_devices";

drop table "public"."user_profiles";

create table "public"."users" (
    "id" bigint generated by default as identity not null,
    "username" text not null,
    "fcm_token" text,
    "created_at" timestamp with time zone default now()
);


alter table "public"."fcm_notifications" drop column "data";

alter table "public"."fcm_notifications" drop column "fcm_message_id";

alter table "public"."fcm_notifications" drop column "fcm_token";

alter table "public"."fcm_notifications" drop column "notification_type";

alter table "public"."fcm_notifications" drop column "user_id";

alter table "public"."fcm_notifications" add column "completed_at" timestamp with time zone;

alter table "public"."fcm_notifications" add column "result" text;

alter table "public"."fcm_notifications" alter column "body" drop not null;

alter table "public"."fcm_notifications" disable row level security;

CREATE UNIQUE INDEX fcm_notifications_pkey ON public.fcm_notifications USING btree (id);

CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id);

alter table "public"."fcm_notifications" add constraint "fcm_notifications_pkey" PRIMARY KEY using index "fcm_notifications_pkey";

alter table "public"."users" add constraint "users_pkey" PRIMARY KEY using index "users_pkey";

grant delete on table "public"."users" to "anon";

grant insert on table "public"."users" to "anon";

grant references on table "public"."users" to "anon";

grant select on table "public"."users" to "anon";

grant trigger on table "public"."users" to "anon";

grant truncate on table "public"."users" to "anon";

grant update on table "public"."users" to "anon";

grant delete on table "public"."users" to "authenticated";

grant insert on table "public"."users" to "authenticated";

grant references on table "public"."users" to "authenticated";

grant select on table "public"."users" to "authenticated";

grant trigger on table "public"."users" to "authenticated";

grant truncate on table "public"."users" to "authenticated";

grant update on table "public"."users" to "authenticated";

grant delete on table "public"."users" to "service_role";

grant insert on table "public"."users" to "service_role";

grant references on table "public"."users" to "service_role";

grant select on table "public"."users" to "service_role";

grant trigger on table "public"."users" to "service_role";

grant truncate on table "public"."users" to "service_role";

grant update on table "public"."users" to "service_role";


