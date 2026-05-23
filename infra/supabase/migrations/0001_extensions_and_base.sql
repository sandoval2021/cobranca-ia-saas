create extension if not exists pgcrypto;

create type app_role as enum ('super_admin', 'owner');
create type subscription_status as enum ('trial', 'active', 'past_due', 'paused', 'blocked', 'canceled');
create type server_status as enum ('ativo', 'instavel', 'fora_do_ar');
create type route_status as enum ('ativa', 'reserva', 'inativa');
create type message_direction as enum ('entrada', 'saida');
