/* 
 * This file contains the sql tables for the KrKit Libraries.
 * These statements work for postgresql.
 */
 

/*
 * The KrKit::Control modules use the following tables.
 */ 

/* 
 * Users that are in the system, they have the same id as from 
 * the master auth tables. 
 */
create sequence "auth_users_seq";
create table "auth_users" (
	"id" 			int4 primary key default nextval('auth_users_seq') NOT NULL,
	"active"		bool,
	"user_name" 	varchar,
	"password"		varchar,
	"first_name" 	varchar,
	"last_name" 	varchar,
	"email" 		varchar
);

/* 
 * These two tables deal with the groups part of authentication and
 * authorization. The define groups and which users are in what groups.
 */
create sequence "auth_groups_seq";
create table "auth_groups" (
	"id" 		int4 primary key default nextval('auth_groups_seq') NOT NULL,
	"name" 		varchar,
	"description" 	text
);

create sequence "auth_group_members_seq";
create table "auth_group_members" (
	"id" 	int4 primary key default nextval('auth_group_members_seq') NOT NULL,
	"user_id"	int4,
	"group_id" 	int4	
);

/* 
 * auth_pages has been replaced with auth_acl
 *
 * create sequence "auth_pages_seq";
 * create table "auth_pages" (
 * "id" 		int4 primary key default nextval('auth_pages_seq') NOT NULL,
 * "perms" 		varchar,
 * "owner_id"	int4,
 * "group_id"	int4,
 * "uri" 		varchar,
 * "title" 		varchar
 * );
 *
 */

/* 
 * auth_acl replaces auth_pages.
 *
 * This is the by page access stuff, keeps what page has what perms
 * page is the uri that we wish to set the level on, 
 * makes us ultra granular and it makes cool.
 */
create sequence "auth_acl_seq";
create table "auth_acl" (
	"id" 			int4 primary key default nextval('auth_acl_seq') NOT NULL,
	"owner_id"		int4,
	"group_id"		int4,
	"perms" 		varchar,
	"uri" 			varchar
);

/* 
 * This is sql for the Helper
 */
create sequence "help_items_seq";
create table "help_items" (
	"id" 			int4 primary key default nextval('help_items_seq') NOT NULL,
	"category_id"	int4,
	"ident"			varchar unique, /* Needs to be unique */
	"created"		timestamp,
	"name"			varchar,
	"content"		text
);

/* Allows a parent/child relationship */
create sequence "help_categories_seq";
create table "help_categories" (
	"id" 	int4 primary key default nextval('help_categories_seq') NOT NULL,
	"parent_id"	int4,
	"ident"		varchar unique, /* Needs to be unique */
	"frame"		varchar,
	"name"		varchar
);

/* 
 * Configuration store.
 */
create sequence "config_seq";
create table "config" (
	"id" 	int4 primary key default nextval('configuration_seq') NOT NULL,
	"host"	varchar, 	/* host this rule applies to */
	"path"	varchar,	/* path on a host */
	"name"	varchar,	/* name of the variable */
	"value" text 		/* config value */
);
