/* 
 * This file contains the sql tables for the KrKit Libraries.
 * These statements work for mysql.
 */
 

/*
 * The KrKit::Control modules use the following tables.
 */ 

/* 
 * Users that are in the system, they have the same id as from 
 * the master auth tables. 
 */
create table auth_users (
	id			mediumint not null unique auto_increment,
	active		bool,
	user_name 	varchar(255),
	password	varchar(255),
	first_name 	varchar(255),
	last_name 	varchar(255),
	email 		varchar(255),
	primary key( id )
);


/* 
 * These two tables deal with the groups part of authentication and
 * authorization. The define groups and which users are in what groups.
 */
create table "auth_groups" (
	id				mediumint not null unique auto_increment,
	name 			varchar(255),
	description 	text,
	primary key( id )
);

create table "auth_group_members" (
	id			medium int not null unique auto_increment,
	user_id		int4,
	group_id 	int4,	
	primary key( id )
);

/* 
 * This is the by page access stuff, keeps what page has what perms
 * page is the uri that we wish to set the level on, 
 * makes us ultra granular and it makes cool.
 */
create table "auth_pages" (
	id				mediumint not null unique auto_increment,
	user_perm		int,
	group_perm		int,
	world_perm 		int,
	owner_id		int,
	group_id		int,
	uri 			varchar(255),
	title 			varchar(255),
	primary key( id )
);

/* 
 * This is sql for the Helper
 */
create table "help_items" (
	id				mediumint not null unique auto_increment,
	category_id		int,
	ident			varchar(255) unique, /* Needs to be unique */
	created			timestamp(14),
	name			varchar(255),
	content			text,
	primary key( id )
);

/* Allows a parent/child relationship */
create sequence "help_categories_seq";
create table "help_categories" (
	id			mediumint not null unique auto_increment,
	parent_id	int,
	ident		varchar(255) unique, /* Needs to be unique */
	name		varchar(255)
);

