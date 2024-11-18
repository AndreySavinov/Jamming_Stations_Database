DROP VIEW stations_for_9_object;
DROP VIEW stations_near_object;
DROP VIEW suppressing_station;
DROP VIEW our_aircraft_targets;
DROP VIEW phase_modulation_sources;

ALTER TABLE "air_friend" DROP CONSTRAINT "air_friend_fk2";

drop table "interference_station";
drop table "ground_objects";
drop table "air_enemy";
drop table "air_friend";
drop table "radiation_source";
drop table "modulations";
drop table "aircraft_types";

DROP USER reader1;
DROP USER reader2;
DROP USER writer1;
DROP USER writer2;

DROP GROUP readers;
DROP GROUP writers;

CREATE GROUP readers;
CREATE GROUP writers;

CREATE USER reader1 WITH PASSWORD 'reader1' NOCREATEDB NOCREATEUSER;
CREATE USER reader2 WITH PASSWORD 'reader2' NOCREATEDB NOCREATEUSER;

CREATE USER writer1 WITH PASSWORD 'writer1' NOCREATEDB NOCREATEUSER;
CREATE USER writer2 WITH PASSWORD 'writer2' NOCREATEDB NOCREATEUSER;

ALTER GROUP readers ADD USER reader1, reader2;
ALTER GROUP writers ADD USER writer1, writer2;


create table "interference_station" (
		"station_id" serial not null,
		"x" float not null,
		"y" float not null,
		"id_department" integer CHECK (id_department > 0 AND id_department < 4),
		"spectral_noise_power" float not null check (spectral_noise_power > 0),
		"low_freq" float not null check (low_freq > 0),
		"high_freq" float not null check (high_freq > low_freq),
		"radius" float not null check (radius>0),
		"target_ground" integer not null DEFAULT 1,
		"target_air" integer not null DEFAULT 0,
		PRIMARY KEY ("station_id")
		);

create table "ground_objects" (
		"object_id" serial not null,
		"x" float not null,
		"y" float not null,
		"area" float not null check (area>0),
		PRIMARY KEY ("object_id")
		);
		
create table "air_enemy" (
		"enemy_id" serial not null,
		"x" float not null,
		"y" float not null,
		"z" float not null check (z>0),
		"speed" float not null check (speed>0),
		"course" float not null check (course>=0 and course<360),
		"scattering_area" float not null check (scattering_area > 0),
		"type" integer not null,
		PRIMARY KEY ("enemy_id")
		);

create table "air_friend" (
		"friend_id" serial not null,
		"x" float not null,
		"y" float not null,
		"z" float not null check (z>0),
		"speed" float not null check (speed>0),
		"course" float not null check (course>=0 and course<360),
		"scattering_area" float not null check (scattering_area > 0),
		"type" integer not null,
		"target" integer not null UNIQUE,
		PRIMARY KEY ("friend_id")
		);
create table "radiation_source" (
		"source_id" serial not null,
		"power" float not null check (power>=0),
		"x" float not null,
		"y" float not null,
		"z" float not null check (z>0),
		"frequency" float not null check (frequency>0),
		"modulation" integer not null,
		PRIMARY KEY ("source_id")
		);
	
create table "modulations" (
		"modulation_id" serial NOT NULL,
		"name_" VARCHAR(255) NOT NULL,
		"description" VARCHAR(255) NOT NULL,
		PRIMARY KEY ("modulation_id")
		);
create table "aircraft_types" (
		"type_id" serial NOT NULL,
		"type" VARCHAR(255) NOT NULL,
		PRIMARY KEY ("type_id")
		);


ALTER TABLE "interference_station" ADD CONSTRAINT "interference_station_fk" FOREIGN KEY ("target_ground") REFERENCES "ground_objects"("object_id");
ALTER TABLE "air_enemy" ADD CONSTRAINT "air_enemy_fk" FOREIGN KEY ("type") REFERENCES "aircraft_types"("type_id");
ALTER TABLE "air_friend" ADD CONSTRAINT "air_friend_fk1" FOREIGN KEY ("type") REFERENCES "aircraft_types"("type_id");
ALTER TABLE "air_friend" ADD CONSTRAINT "air_friend_fk2" FOREIGN KEY ("target") REFERENCES "air_enemy"("enemy_id");
ALTER TABLE "radiation_source" ADD CONSTRAINT "radiation_source_fk" FOREIGN KEY ("modulation") REFERENCES "modulations"("modulation_id");


-- Grants
GRANT SELECT ON TABLE "interference_station" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "interference_station" TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "interference_station_station_id_seq" TO GROUP writers;

GRANT SELECT ON TABLE "ground_objects" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "ground_objects" TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "ground_objects_object_id_seq" TO GROUP writers;

GRANT SELECT ON TABLE "air_enemy" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "air_enemy" TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "air_enemy_enemy_id_seq" TO GROUP writers;

GRANT SELECT ON TABLE "air_friend" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "air_friend"  TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "air_friend_friend_id_seq"  TO GROUP writers;

GRANT SELECT ON TABLE "radiation_source" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "radiation_source" TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "radiation_source_source_id_seq" TO GROUP writers;

GRANT SELECT ON TABLE "modulations" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "modulations" TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "modulations_modulation_id_seq" TO GROUP writers;

GRANT SELECT ON TABLE "aircraft_types" TO GROUP readers;
GRANT INSERT, UPDATE, DELETE ON TABLE "aircraft_types" TO GROUP writers;
GRANT SELECT, UPDATE ON TABLE "aircraft_types_type_id_seq" TO GROUP writers;

-- FUNCTION
CREATE OR REPLACE FUNCTION covering_station(float, float) RETURNS integer AS '
DECLARE
    result integer;
BEGIN
    SELECT station_id INTO result FROM "interference_station" station 
    WHERE (POWER(station.x - $1, 2)+ POWER(station.y - $2, 2) <= station.radius);
    RETURN result;
END;
' LANGUAGE plpgsql;

-- TRIGGER
CREATE OR REPLACE FUNCTION assign_target_air() RETURNS trigger AS '
DECLARE
    result varchar;
BEGIN
    UPDATE "interference_station"
    SET target_air = NEW.source_id
    WHERE (low_freq < NEW.frequency)
    AND (high_freq > NEW.frequency)
    AND (POWER(x-NEW.x, 2)+POWER(y-NEW.y, 2) <= POWER(radius, 2))
    AND (target_air = 0);    
    RETURN result;
END;' LANGUAGE plpgsql;

CREATE TRIGGER ASSIGN_DUTY_STATIONS AFTER INSERT ON "radiation_source" FOR EACH ROW EXECUTE PROCEDURE assign_target_air();

-- VIEWS
CREATE VIEW stations_for_9_object AS
SELECT station_id as "Станция #", spectral_noise_power as "Спектральная мощность" ,
	low_freq || ' ' || high_freq as "Диапазон"
	FROM "interference_station"
	WHERE target_ground = 9;

CREATE VIEW stations_near_object AS --!!!!!!!
SELECT station_id as "Станция #", x || ' ' || y as "Координаты",
	radius as "Радиус"
	FROM "interference_station"
	WHERE POWER(x+40, 2) + POWER(y-30, 2) <= POWER(20, 2);

CREATE VIEW suppressing_station AS
SELECT s.station_id as "Станция #", s.x || ' ' || s.y as "Координаты",
	s.id_department as "Рота #", s.target_ground as "Объект прикрытия #"
	FROM "interference_station" s, "radiation_source" r
	WHERE r.power < s.spectral_noise_power*(s.high_freq-s.low_freq)
	AND (POWER(r.x - s.x,2)+POWER(r.y - s.y,2)<=POWER(s.radius,2));

CREATE VIEW our_aircraft_targets AS
SELECT f.friend_id as "Свой #", f.type as "Тип СВН1",
	e.enemy_id as "Чужой #", e.type as "Тип СВН2"
	FROM "air_enemy" e, "air_friend" f
	WHERE f.target = e.enemy_id;

CREATE VIEW phase_modulation_sources AS
SELECT s.source_id as "Источник излучения #", mod.name_ || ' ' || 
	mod.description as "Модуляция", s.power "Мощность "
	FROM "radiation_source" s, "modulations" mod
	WHERE s.modulation = 2
	AND mod.modulation_id = 2; 

--COPY "modulations" (modulation_id, name_, description) FROM stdin;
INSERT INTO "modulations"(modulation_id, name_, description) VALUES (1, 'AM', 'amplitude');
INSERT INTO "modulations"(modulation_id, name_, description) VALUES (2, 'PM', 'phase');
INSERT INTO "modulations"(modulation_id, name_, description) VALUES (3, 'FM', 'frequncy');
INSERT INTO "modulations"(modulation_id, name_, description) VALUES (4, 'AFM', 'amplitude-frequency');
INSERT INTO "modulations"(modulation_id, name_, description) VALUES (5, 'APM', 'amplitude-phase');
INSERT INTO "modulations"(modulation_id, name_, description) VALUES (6, 'IMP', 'impulse signal');

INSERT INTO "aircraft_types" (type_id, type) VALUES (1, 'Fighter');
INSERT INTO "aircraft_types" (type_id, type) VALUES (2, 'Attack plane');
INSERT INTO "aircraft_types" (type_id, type) VALUES (3, 'Bomber');
INSERT INTO "aircraft_types" (type_id, type) VALUES (4, 'See plane');
INSERT INTO "aircraft_types" (type_id, type) VALUES (5, 'Jammer');
INSERT INTO "aircraft_types" (type_id, type) VALUES (6, 'Carrier');
INSERT INTO "aircraft_types" (type_id, type) VALUES (7, 'Cruise missile');
INSERT INTO "aircraft_types" (type_id, type) VALUES (8, 'Anti-radar missile');

INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (1, -19.23, -48.58, 206.5, 736.51, 264.95, 3.54, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (2, -43.38, 36.47, 204.69, 767.29, 180.87, 2.41, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (3, -38.93, -3.41, 101.9, 919.99, 342.52, 3.73, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (4, -22.62, 7.53, 47.58, 416.59, 152.16, 8.54, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (5, -20.52, -29.11, 38.6, 785.67, 61.12, 8.05, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (6, 49.28, -6.41, 119.73, 998.64, 192.59, 3.39, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (7, 0.47, -20.01, 215.44, 506.31, 68.28, 7.53, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (8, 8.41, -17.82, 97.38, 394.21, 173.6, 8.49, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (9, 45.49, -44.62, 85.89, 813.85, 334.41, 2.83, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (10, 11.13, 4.98, 252.44, 622.74, 320.97, 2.38, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (11, 14.61, -46.42, 167.63, 717.68, 307.95, 5.55, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (12, -13.54, -32.46, 297.37, 244.59, 296.54, 2.5, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (13, 15.54, 28.65, 272.77, 693.03, 192.43, 7.98, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (14, -49.69, -17.22, 299.58, 716.61, 257.39, 2.55, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (15, 21.66, -10.96, 104.07, 206.26, 281.32, 9.14, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (16, -5.67, 8.05, 282.58, 975.27, 249.76, 7.76, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (17, 0.12, 2.09, 134.77, 793.28, 322.42, 2.13, 8);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (18, -40.92, -9.96, 86.45, 766.02, 236.29, 9.95, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (19, -19.01, -48.62, 37.66, 939.31, 159.97, 2.22, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (20, 36.98, 7.8, 271.64, 451.12, 66.2, 1.87, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (21, 25.4, -39.68, 247.83, 814.78, 260.76, 8.08, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (22, -2.68, -6.17, 198.26, 990.71, 287.25, 6.26, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (23, -42.05, -37.59, 83.56, 611.1, 70.1, 6.32, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (24, -40.76, -1.17, 209.46, 796.8, 174.46, 5.36, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (25, 46.96, 44.83, 158.24, 230.02, 249.49, 2.96, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (26, -24.2, -11.56, 225.76, 493.7, 210.1, 1.47, 8);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (27, -10.45, -47.24, 178.8, 492.55, 5.48, 3.52, 8);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (28, -6.32, -12.66, 137.13, 958.06, 308.95, 0.64, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (29, -14.32, 6.86, 99.45, 747.57, 85.11, 5.03, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (30, -11.15, -30.68, 269.38, 399.12, 78.18, 1.11, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (31, 30.21, 8.27, 43.88, 319.35, 340.76, 8.57, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (32, 43.57, 49.52, 158.86, 858.84, 280.91, 5.32, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (33, 42.38, -36.84, 244.81, 884.23, 254.98, 9.61, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (34, 9.67, 23.62, 209.03, 552.81, 248.68, 7.27, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (35, 30.33, -35.98, 165.51, 263.84, 48.74, 9.63, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (36, 21.08, 27.11, 38.17, 906.44, 237.35, 1.4, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (37, 17.35, 47.76, 33.77, 957.94, 287.64, 8.78, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (38, -27.17, 6.2, 186.74, 598.59, 136.74, 7.72, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (39, -36.53, -14.86, 221.17, 320.13, 162.6, 3.48, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (40, -11.52, 47.47, 22.66, 345.7, 159.41, 4.24, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (41, 3.85, 41.86, 209.2, 343.96, 222.31, 9.29, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (42, -39.2, 44.67, 24.3, 618.56, 319.74, 7.7, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (43, -8.82, 8.13, 34.16, 363.18, 8.28, 1.44, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (44, -38.5, -34.14, 222.2, 971.4, 206.92, 5.08, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (45, -13.13, -42.07, 293.32, 413.45, 226.88, 5.01, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (46, -24.26, 18.28, 163.9, 827.57, 190.43, 4.31, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (47, 1.61, -43.35, 107.83, 940.78, 226.56, 3.36, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (48, -40.79, 8.53, 188.66, 922.73, 309.63, 9.4, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (49, 8.24, 34.49, 248.36, 203.21, 31.65, 4.2, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (50, 30.19, -13.09, 140.64, 467.2, 296.02, 1.14, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (51, -32.19, -0.05, 251.62, 357.66, 336.38, 6.9, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (52, -43.55, 8.41, 48.11, 371.6, 139.0, 6.58, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (53, -10.17, -32.69, 87.6, 984.46, 155.4, 2.34, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (54, -20.34, -45.01, 165.0, 820.93, 109.13, 5.02, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (55, -36.42, 3.45, 87.01, 270.48, 91.18, 2.23, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (56, -39.77, -41.49, 258.14, 419.8, 336.51, 8.91, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (57, 9.75, -39.54, 218.75, 297.35, 175.06, 1.33, 8);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (58, 47.45, 40.37, 248.98, 752.89, 251.89, 1.65, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (59, -11.16, 29.64, 108.62, 215.33, 39.5, 5.81, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (60, 3.08, 36.82, 262.56, 305.73, 255.63, 9.21, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (61, -30.85, 15.56, 191.32, 316.81, 76.16, 6.71, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (62, 3.66, 22.06, 150.87, 798.96, 24.1, 8.52, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (63, -24.39, -4.3, 63.31, 835.46, 162.81, 6.77, 1);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (64, -41.54, 36.81, 240.75, 385.81, 296.74, 1.72, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (65, 39.59, 28.11, 9.16, 523.64, 177.12, 8.57, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (66, 29.25, -12.25, 143.05, 360.13, 95.72, 6.56, 4);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (67, 1.65, 6.56, 237.57, 992.88, 184.5, 5.58, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (68, 17.83, 42.45, 239.34, 857.17, 302.12, 9.95, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (69, -5.68, -43.85, 134.78, 368.91, 164.79, 8.64, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (70, -11.64, -43.03, 121.91, 718.41, 335.58, 2.27, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (71, -40.81, -11.27, 161.64, 451.27, 218.15, 9.17, 3);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (72, 14.27, -47.2, 289.23, 328.12, 16.15, 5.53, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (73, -4.8, 10.39, 118.85, 547.22, 83.32, 8.68, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (74, 48.88, -42.92, 97.21, 610.79, 351.42, 0.61, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (75, -20.54, 9.98, 41.57, 753.32, 348.16, 7.92, 6);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (76, -19.69, 25.26, 7.81, 263.77, 266.46, 4.97, 7);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (77, -38.06, -46.03, 266.54, 974.04, 121.2, 0.9, 8);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (78, -45.09, -42.38, 11.1, 460.29, 150.77, 6.6, 2);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (79, 41.71, 27.36, 29.44, 518.56, 204.37, 5.66, 5);
INSERT INTO "air_enemy" (enemy_id, x, y, z, speed, course, scattering_area, type) VALUES (80, -27.73, -17.33, 262.09, 590.87, 195.56, 0.53, 7);

INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (1, -9.85, -26.56, 171.73, 238.44, 7.13, 1.32, 2, 57);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (2, -19.22, 46.43, 3.89, 509.3, 15.95, 7.1, 2, 56);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (3, 2.03, -33.8, 232.43, 365.51, 353.27, 8.64, 2, 18);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (4, 48.65, -14.55, 0.65, 987.09, 266.55, 5.85, 4, 40);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (5, -33.72, -5.58, 56.02, 756.26, 280.98, 3.68, 4, 29);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (6, 28.53, -39.84, 204.5, 243.95, 46.93, 6.27, 1, 66);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (7, 32.26, 38.48, 164.61, 477.02, 32.43, 1.05, 4, 23);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (8, 14.48, 31.57, 10.59, 632.47, 347.05, 1.42, 4, 10);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (9, 10.05, 1.65, 260.59, 276.48, 260.17, 3.05, 1, 80);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (10, -16.82, -11.9, 221.27, 787.82, 324.78, 4.13, 4, 65);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (11, 48.51, 11.7, 266.85, 479.6, 160.88, 9.09, 1, 33);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (12, -35.02, -34.96, 163.58, 735.55, 77.04, 9.79, 1, 37);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (13, 15.42, 35.78, 110.54, 651.87, 242.4, 1.96, 4, 27);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (14, -45.33, 15.66, 218.62, 568.03, 149.56, 2.99, 1, 34);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (15, 3.67, -17.41, 268.85, 298.78, 212.15, 8.56, 4, 72);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (16, 16.35, 27.0, 92.13, 821.01, 89.46, 6.17, 2, 43);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (17, 3.84, -23.28, 25.22, 539.26, 55.18, 4.92, 1, 9);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (18, 46.84, -32.86, 249.47, 453.51, 316.88, 7.28, 1, 59);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (19, 7.15, 3.07, 125.76, 296.95, 12.14, 6.53, 1, 2);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (20, 0.92, -13.98, 244.99, 304.12, 230.49, 1.01, 2, 46);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (21, 15.08, -28.95, 160.87, 974.16, 29.42, 6.1, 2, 75);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (22, -32.75, -30.72, 210.38, 693.43, 233.11, 3.06, 4, 53);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (23, 13.49, -11.23, 137.17, 333.83, 358.28, 7.88, 4, 11);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (24, -18.79, 17.92, 80.96, 562.77, 156.88, 9.94, 4, 68);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (25, 39.32, -46.36, 201.31, 476.42, 256.47, 6.72, 1, 60);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (26, 3.55, 21.26, 166.1, 996.15, 231.92, 9.0, 1, 51);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (27, 33.73, -15.49, 278.93, 275.81, 323.34, 1.75, 4, 14);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (28, 35.97, 43.8, 120.6, 777.81, 302.89, 3.62, 1, 16);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (29, -4.15, 47.63, 256.64, 344.2, 149.65, 7.3, 4, 69);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (30, -34.54, 24.26, 92.43, 976.65, 353.35, 6.37, 1, 24);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (31, 20.51, -44.84, 289.12, 883.7, 336.84, 5.08, 4, 1);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (32, -1.46, -21.05, 66.6, 752.57, 179.49, 1.45, 1, 61);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (33, -16.96, -39.42, 53.49, 610.68, 198.08, 1.38, 1, 55);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (34, 5.17, 18.79, 98.61, 487.57, 293.35, 4.25, 1, 70);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (35, 0.49, 40.26, 149.22, 210.95, 54.97, 4.15, 2, 12);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (36, -37.48, -41.26, 244.01, 483.33, 340.12, 3.8, 1, 50);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (37, -43.56, -0.56, 149.36, 707.74, 90.64, 1.74, 4, 31);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (38, 5.3, 6.09, 165.36, 452.5, 304.97, 5.38, 4, 73);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (39, -18.23, -36.47, 33.77, 860.76, 24.12, 2.1, 2, 42);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (40, -38.32, -23.79, 83.99, 430.37, 297.46, 7.43, 1, 49);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (41, 4.14, 30.82, 32.46, 893.93, 70.94, 4.35, 4, 26);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (42, 12.58, -41.5, 123.04, 517.1, 41.5, 9.96, 2, 15);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (43, 33.05, 1.33, 111.75, 305.88, 99.54, 6.11, 1, 20);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (44, 42.19, -7.52, 94.46, 416.26, 294.24, 7.8, 1, 19);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (45, 0.85, 45.8, 104.38, 826.32, 30.92, 5.27, 1, 52);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (46, 11.13, 20.88, 41.25, 797.69, 251.06, 9.54, 2, 30);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (47, 41.38, -11.38, 194.89, 444.37, 46.74, 8.58, 4, 74);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (48, 7.71, 30.16, 198.89, 927.9, 288.63, 8.63, 1, 32);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (49, -2.62, -20.63, 240.06, 740.63, 345.4, 7.43, 1, 28);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (50, -19.84, 1.88, 190.28, 759.95, 252.78, 9.46, 1, 7);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (51, -1.45, -38.8, 245.38, 516.86, 341.41, 2.43, 1, 6);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (52, 29.1, -13.76, 222.97, 761.13, 240.55, 5.14, 4, 64);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (53, -45.87, 18.54, 158.61, 901.45, 73.03, 6.16, 1, 5);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (54, -4.16, -33.62, 205.33, 970.65, 74.11, 2.73, 1, 79);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (55, -43.51, -7.7, 269.91, 447.38, 303.03, 1.3, 1, 3);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (56, 7.56, 12.98, 80.34, 557.19, 12.36, 7.79, 4, 22);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (57, -47.81, 26.19, 290.87, 270.9, 169.45, 6.34, 4, 58);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (58, -15.17, 47.07, 200.47, 858.77, 297.81, 2.63, 2, 13);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (59, -1.1, 40.91, 69.48, 641.91, 2.07, 9.87, 4, 63);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (60, 24.81, 3.51, 143.8, 262.61, 228.2, 5.0, 2, 71);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (61, 6.47, -40.97, 85.44, 850.07, 29.55, 5.01, 4, 35);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (62, -47.82, 34.43, 227.32, 973.97, 192.58, 3.85, 4, 44);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (63, 15.67, -37.02, 80.77, 396.32, 346.79, 5.99, 2, 76);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (64, 14.53, 23.55, 165.64, 512.62, 284.29, 4.31, 1, 78);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (65, -38.25, 18.55, 203.91, 863.39, 184.24, 9.27, 2, 38);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (66, -7.86, 21.82, 207.7, 731.69, 31.2, 3.53, 2, 47);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (67, 3.8, 34.37, 45.78, 429.64, 253.36, 4.12, 1, 67);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (68, 12.61, 43.47, 192.64, 845.88, 136.22, 1.56, 1, 62);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (69, -12.63, -21.63, 67.43, 384.28, 10.47, 5.7, 2, 21);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (70, 41.11, 29.18, 88.47, 778.67, 221.38, 7.69, 4, 36);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (71, -6.42, -10.5, 57.04, 824.56, 51.16, 2.66, 1, 45);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (72, 40.13, 39.95, 148.57, 250.96, 146.14, 4.35, 4, 8);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (73, 16.92, -3.01, 267.34, 393.7, 21.71, 9.45, 4, 41);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (74, 47.7, -40.86, 39.88, 912.75, 129.5, 5.13, 2, 25);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (75, -47.33, -19.81, 59.8, 580.13, 66.56, 9.32, 1, 17);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (76, -45.5, 23.62, 254.34, 354.28, 58.9, 3.19, 2, 54);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (77, -20.09, -4.64, 11.85, 379.28, 332.02, 0.77, 4, 48);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (78, 48.31, 27.8, 114.27, 668.14, 138.43, 1.59, 4, 39);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (79, 1.48, -6.63, 8.09, 370.13, 54.18, 3.04, 1, 77);
INSERT INTO "air_friend" (friend_id, x, y, z, speed, course, scattering_area, type, target) VALUES (80, 41.15, 12.92, 274.33, 361.76, 55.47, 6.8, 2, 4);

INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (1, 37.78, -7.04, 51.61);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (2, 7.46, 37.73, 77.86);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (3, 31.92, 47.53, 67.85);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (4, 35.24, -21.13, 58.95);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (5, 47.56, 35.4, 45.92);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (6, 41.46, 29.68, 56.48);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (7, -7.2, 33.4, 48.97);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (8, -10.5, 15.19, 94.46);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (9, -45.12, -17.6, 31.85);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (10, -14.52, 7.18, 67.4);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (11, -15.61, -31.14, 72.53);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (12, -5.56, 47.39, 54.42);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (13, 34.26, -4.79, 35.06);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (14, 17.65, 22.02, 31.41);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (15, -5.53, -49.91, 39.73);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (16, -8.3, 10.29, 50.29);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (17, 9.2, 28.59, 27.55);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (18, -33.29, -9.63, 58.41);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (19, 49.92, -46.77, 29.16);
INSERT INTO "ground_objects" (object_id, x, y, area) VALUES (20, 48.44, 8.84, 54.6);

INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (1, 42.58, -21.35, 1, 88, 35, 78, 7, 18);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (2, 26.19, 7.29, 1, 82, 48, 72, 8, 9);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (3, 17.33, -41.28, 1, 60, 45, 61, 10, 12);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (4, -24.27, 46.4, 1, 68, 38, 97, 5, 9);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (5, 36.35, -19.54, 1, 90, 39, 80, 6, 6);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (6, 11.87, 36.59, 1, 56, 46, 73, 10, 11);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (7, -21.28, 32.42, 1, 78, 20, 77, 10, 3);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (8, 16.98, 6.56, 1, 67, 48, 70, 6, 5);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (9, -39.76, -20.16, 1, 56, 48, 71, 5, 7);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (10, -33.03, 16.27, 2, 65, 38, 68, 9, 2);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (11, -25.4, 18.95, 2, 81, 36, 69, 7, 11);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (12, -7.78, 44.18, 2, 79, 47, 75, 8, 8);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (13, 41.33, 18.56, 2, 55, 37, 97, 8, 12);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (14, 26.68, 19.55, 2, 68, 46, 92, 8, 13);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (15, 24.29, -32.82, 2, 84, 36, 77, 5, 20);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (16, -26.79, 27.15, 2, 80, 47, 67, 8, 11);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (17, -21.21, -10.51, 2, 76, 44, 78, 9, 7);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (18, -4.26, -35.44, 2, 56, 27, 77, 9, 20);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (19, -24.98, -2.26, 3, 74, 43, 82, 9, 9);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (20, 16.2, -27.28, 3, 70, 50, 98, 9, 7);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (21, 42.97, 24.65, 3, 83, 33, 95, 10, 3);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (22, -13.62, -45.57, 3, 57, 30, 65, 6, 10);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (23, 44.21, 12.77, 3, 51, 26, 78, 9, 6);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (24, -36.08, -48.82, 3, 78, 38, 60, 9, 5);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (25, 47.65, -30.55, 3, 86, 36, 63, 7, 3);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (26, 24.34, 26.61, 3, 63, 46, 89, 9, 6);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (27, -26.52, -30.84, 3, 52, 31, 85, 7, 15);
INSERT INTO "interference_station" (station_id, x, y, id_department, spectral_noise_power, low_freq, high_freq, radius, target_ground) VALUES (28, 0, 0, 3, 52, 31, 85, 7, 15);

INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (1, 495.73, -35.63, -40.35, 289.73, 20.43, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (2, 438.99, -11.43, -40.04, 241.5, 26.15, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (3, 53.68, 36.94, -48.93, 163.29, 95.17, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (4, 281.65, -41.26, -9.81, 54.05, 69.77, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (5, 53.29, -27.11, 10.3, 211.73, 96.05, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (6, 17.02, -43.77, -49.88, 228.45, 98.42, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (7, 490.05, -7.29, 33.61, 171.29, 25.76, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (8, 7.02, -15.6, 40.83, 97.41, 5.46, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (9, 301.75, -45.02, -39.88, 143.09, 81.14, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (10, 270.72, -0.05, 21.24, 139.27, 32.02, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (11, 84.39, 41.28, -45.16, 77.97, 29.18, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (12, 240.18, 16.72, -9.73, 0.6, 0.59, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (13, 118.06, -20.37, -1.32, 283.8, 80.77, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (14, 35.79, -7.13, -43.83, 68.43, 86.2, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (15, 122.26, 29.29, 41.37, 289.48, 67.05, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (16, 463.98, -4.75, 11.68, 153.5, 41.78, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (17, 426.63, 46.8, -6.89, 203.14, 28.95, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (18, 223.17, -40.53, -9.93, 51.01, 87.81, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (19, 474.33, 27.16, -7.28, 160.25, 36.87, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (20, 129.91, 21.78, 19.54, 197.65, 37.32, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (21, 92.66, -31.0, -20.69, 227.71, 83.13, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (22, 112.39, 6.78, 47.75, 190.95, 29.17, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (23, 416.68, -31.04, -49.72, 188.07, 98.86, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (24, 439.42, -41.62, 17.33, 42.75, 79.94, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (25, 418.01, 23.59, 21.74, 64.67, 49.31, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (26, 216.79, -1.04, -10.59, 274.54, 78.97, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (27, 281.89, -8.49, 30.68, 122.0, 56.93, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (28, 232.0, -33.86, -20.42, 243.36, 10.69, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (29, 180.61, 4.3, 25.04, 27.45, 61.05, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (30, 195.4, 49.98, -31.54, 205.15, 42.15, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (31, 336.57, -8.8, -14.91, 253.38, 97.0, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (32, 37.98, 14.47, 45.62, 39.72, 12.7, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (33, 428.24, -35.56, -24.53, 8.81, 12.33, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (34, 92.18, -48.64, 7.29, 72.93, 95.49, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (35, 397.58, 22.2, 48.08, 293.72, 42.73, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (36, 364.23, 47.77, 24.13, 83.54, 32.13, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (37, 154.34, 3.5, 11.97, 41.43, 19.33, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (38, 56.36, -33.8, 32.92, 213.67, 29.27, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (39, 73.18, 16.72, -7.71, 260.35, 54.75, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (40, 466.02, -29.87, -1.23, 211.23, 31.14, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (41, 260.24, -18.74, -13.4, 288.67, 5.22, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (42, 153.12, -34.71, 31.5, 214.74, 66.16, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (43, 443.81, 6.37, 9.54, 247.01, 99.1, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (44, 306.34, 44.71, -49.39, 218.09, 43.01, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (45, 476.41, -38.9, 49.38, 204.91, 17.97, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (46, 255.29, 14.38, -24.23, 71.34, 58.96, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (47, 327.53, 48.65, 21.68, 274.34, 42.64, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (48, 151.26, -19.71, -14.52, 21.92, 10.18, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (49, 336.45, 16.08, -29.73, 238.06, 10.27, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (50, 348.31, -37.83, 3.14, 284.01, 8.54, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (51, 191.34, -3.29, 15.31, 203.75, 67.16, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (52, 354.73, 47.46, 26.09, 140.43, 75.66, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (53, 441.31, 40.1, -43.74, 68.93, 0.12, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (54, 360.38, 4.61, 38.84, 45.27, 9.74, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (55, 215.49, -12.84, 48.98, 219.13, 84.88, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (56, 19.86, 3.35, 37.95, 228.49, 52.2, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (57, 192.43, -38.7, -0.17, 59.08, 58.44, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (58, 369.39, -21.7, -3.79, 290.23, 0.53, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (59, 337.23, -26.91, 21.84, 293.31, 65.57, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (60, 49.66, 32.48, 10.29, 19.46, 82.9, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (61, 32.79, -41.05, 21.43, 259.58, 2.97, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (62, 92.34, 33.39, -30.73, 56.58, 35.09, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (63, 414.96, 15.73, 25.71, 141.35, 80.68, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (64, 328.04, 26.67, -28.78, 248.64, 76.33, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (65, 213.89, 33.93, 41.43, 43.1, 14.44, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (66, 203.64, 4.7, -13.17, 27.52, 64.81, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (67, 330.7, 0.58, 31.69, 180.2, 71.72, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (68, 355.51, -5.14, 14.73, 223.02, 92.44, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (69, 70.15, 22.29, 3.07, 182.24, 85.4, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (70, 85.85, 29.68, -40.08, 239.92, 94.5, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (71, 473.93, -4.81, -22.07, 143.52, 66.29, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (72, 443.08, 29.14, 12.92, 31.87, 85.1, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (73, 437.85, -34.66, 45.02, 36.52, 81.36, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (74, 268.9, 35.01, 33.21, 93.2, 20.02, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (75, 259.49, 27.87, 46.99, 86.67, 26.51, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (76, 104.85, 35.39, 30.3, 237.36, 39.15, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (77, 287.01, 22.3, -1.67, 122.68, 86.21, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (78, 450.2, 16.74, 9.26, 223.87, 62.86, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (79, 484.58, 45.4, 38.55, 35.34, 86.98, 4);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (80, 263.52, 20.91, 28.91, 20.99, 49.44, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (81, 139.58, -49.05, -10.34, 129.74, 27.35, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (82, 406.54, -11.08, -12.9, 103.2, 36.33, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (83, 131.29, 5.09, 43.31, 112.99, 56.39, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (84, 11.32, -36.02, -2.83, 156.53, 34.67, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (85, 315.27, 40.91, 45.1, 49.0, 92.97, 3);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (86, 285.61, 15.59, 40.0, 236.05, 51.99, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (87, 141.64, -37.03, 22.87, 282.47, 60.42, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (88, 385.05, -46.9, 5.5, 212.5, 44.77, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (89, 166.65, -6.17, -48.74, 156.89, 10.95, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (90, 369.4, 25.19, -45.17, 272.36, 85.42, 5);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (91, 75.95, -37.8, 21.71, 58.23, 20.2, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (92, 234.46, -37.97, -42.77, 199.28, 20.55, 6);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (93, 74.13, 24.38, 16.53, 122.69, 52.33, 2);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (94, 145.91, 34.77, -7.25, 126.43, 80.73, 1);
INSERT INTO "radiation_source" (source_id, power, x, y, z, frequency, modulation) VALUES (95, 50, 2, 2, 126.43, 80.73, 1);

--VIEWS
SELECT * FROM stations_for_9_object;

SELECT * FROM stations_near_object;

SELECT * FROM our_aircraft_targets;

SELECT * FROM suppressing_station;

SELECT * FROM phase_modulation_sources;

--TRIGGER
SELECT * FROM "interference_station" WHERE target_air !=0;

--FUNCTION

SELECT * FROM covering_station(-26, 27);

-- \c voenka writer1
