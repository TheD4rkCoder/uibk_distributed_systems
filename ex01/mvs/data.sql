-- Drop the not null constraint
ALTER TABLE USERX ALTER COLUMN CREATE_USER_ID DROP NOT NULL;

-- Insert users into USERX table
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Super', 'User', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'superuser', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Admin', 'Istrator', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'admin', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Susi', 'Kaufgern', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'user1', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Max', 'Mustermann', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'user2', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Elvis', 'The King', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'elvis', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Raspberry', 'Pi', '{noop}d3bugrpi-dbug-t3st-dbug-dbgr4spb3rry', 'raspberry-d3bugrpi-dbug-t3st-dbug-dbgr4spb3rry', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Anna', 'Gruber', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'dephead1', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Thomas', 'Berger', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'dephead2', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Lisa', 'Schmidt', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp1', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Karl', 'Huber', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp2', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Maria', 'Wagner', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp3', NULL, '2024-01-01 00:00:00');
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'building', 'manager', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'building_manager', NULL, '2024-01-01 00:00:00');

-- Insert roles
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superuser'), 'ADMIN');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superuser'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superuser'), 'MANAGER');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superuser'), 'DEPARTMENT_HEAD');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superuser'), 'BUILDING_MANAGER');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'admin'), 'ADMIN');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'admin'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'user1'), 'MANAGER');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'user1'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'user2'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'elvis'), 'ADMIN');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'elvis'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'raspberry-d3bugrpi-dbug-t3st-dbug-dbgr4spb3rry'), 'RASPBERRY_PI');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'dephead1'), 'DEPARTMENT_HEAD');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'dephead1'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'dephead2'), 'DEPARTMENT_HEAD');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'dephead2'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'emp1'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'emp2'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'emp3'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'building_manager'), 'BUILDING_MANAGER');

INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE)
VALUES (TRUE, 'Super', 'Admin', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'superadmin', NULL, '2024-01-01 00:00:00');

INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), 'ADMIN');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), 'BUILDING_MANAGER');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), 'MANAGER');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), 'DEPARTMENT_HEAD');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), 'EMPLOYEE');
INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), 'RASPBERRY_PI');

-- Update CREATE_USER_ID fields after the initial insert
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'admin';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'user1';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'user2';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'elvis') WHERE USERNAME = 'elvis';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'raspberry-d3bugrpi-dbug-t3st-dbug-dbgr4spb3rry';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'dephead1';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'dephead2';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'superadmin';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'emp1';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'emp2';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'emp3';
UPDATE USERX SET CREATE_USER_ID = (SELECT ID FROM USERX WHERE USERNAME = 'admin') WHERE USERNAME = 'building_manager';

-- Add the not null constraint back
ALTER TABLE USERX ALTER COLUMN CREATE_USER_ID SET NOT NULL;

-- Seed departments
INSERT INTO DEPARTMENT (NAME, DEPARTMENT_HEAD_ID)
VALUES ('Engineering', (SELECT ID FROM USERX WHERE USERNAME = 'dephead1'));
INSERT INTO DEPARTMENT (NAME, DEPARTMENT_HEAD_ID)
VALUES ('Human Resources', (SELECT ID FROM USERX WHERE USERNAME = 'dephead2'));

-- Assign users to departments
UPDATE USERX SET DEPARTMENT_ID = (SELECT ID FROM DEPARTMENT WHERE NAME = 'Engineering')
WHERE USERNAME IN ('dephead1', 'user1', 'emp1', 'emp2');
UPDATE USERX SET DEPARTMENT_ID = (SELECT ID FROM DEPARTMENT WHERE NAME = 'Human Resources')
WHERE USERNAME IN ('dephead2', 'user2', 'emp3');

-- Buildings
INSERT INTO BUILDING (ID, NAME, NUMBER_OF_FLOORS) VALUES (1000, 'Building A', 5);
INSERT INTO BUILDING (ID, NAME, NUMBER_OF_FLOORS) VALUES (2000, 'Building B', 10);
INSERT INTO BUILDING (ID, NAME, NUMBER_OF_FLOORS) VALUES (3000, 'Building C', 15);

-- Building A, Floor 1
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (1000, 'Lobby A1', 1000, 1, 20, 20, 180, 120);
INSERT INTO COMMON_SPACE (ID) VALUES (1000);
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (2000, 'Engineering Office', 1000, 1, 220, 20, 280, 150);
INSERT INTO OFFICE_SPACE (ID, MIN_OCCUPANCY) VALUES (2000, 5);
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (2100, 'HR Satellite A1', 1000, 1, 520, 20, 220, 150);
INSERT INTO OFFICE_SPACE (ID, MIN_OCCUPANCY) VALUES (2100, 5);

-- Building A, Floor 2
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (2200, 'Engineering Lab', 1000, 2, 20, 20, 300, 160);
INSERT INTO OFFICE_SPACE (ID, MIN_OCCUPANCY) VALUES (2200, 5);
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (2300, 'Meeting Room A2', 1000, 2, 340, 20, 240, 140);
INSERT INTO COMMON_SPACE (ID) VALUES (2300);

-- Building B, Floor 1
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (3000, 'HR Main Office', 2000, 1, 20, 20, 300, 160);
INSERT INTO OFFICE_SPACE (ID, MIN_OCCUPANCY) VALUES (3000, 5);
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (3100, 'Reception B1', 2000, 1, 340, 20, 220, 140);
INSERT INTO COMMON_SPACE (ID) VALUES (3100);

-- Assign users to office spaces
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (2000, (SELECT ID FROM USERX WHERE USERNAME = 'dephead1'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (2000, (SELECT ID FROM USERX WHERE USERNAME = 'user1'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (2000, (SELECT ID FROM USERX WHERE USERNAME = 'emp1'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (2100, (SELECT ID FROM USERX WHERE USERNAME = 'emp3'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (2200, (SELECT ID FROM USERX WHERE USERNAME = 'emp2'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (3000, (SELECT ID FROM USERX WHERE USERNAME = 'dephead2'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (3000, (SELECT ID FROM USERX WHERE USERNAME = 'user2'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES (3000, (SELECT ID FROM USERX WHERE USERNAME = 'emp3'));

-- Seed absences
INSERT INTO ABSENCE (USER_ID, START_DATE, END_DATE, TYPE, ALL_DAY, COMMENT)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'emp1'), '2026-05-05T08:00:00+02:00', '2026-05-09T18:00:00+02:00', 'VACATION', FALSE, 'Spring holiday');
INSERT INTO ABSENCE (USER_ID, START_DATE, END_DATE, TYPE, ALL_DAY, COMMENT)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'emp2'), '2026-04-14T08:00:00+02:00', '2026-04-16T18:00:00+02:00', 'SICK', FALSE, NULL);
INSERT INTO ABSENCE (USER_ID, START_DATE, END_DATE, TYPE, ALL_DAY, COMMENT)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'user1'), '2026-04-21T09:00:00+02:00', '2026-04-25T17:00:00+02:00', 'OTHER', FALSE, 'Conference');
INSERT INTO ABSENCE (USER_ID, START_DATE, END_DATE, TYPE, ALL_DAY, COMMENT)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'user2'), '2026-04-01T00:00:00+02:00', '2026-07-01T00:00:00+02:00', 'PARENTAL', FALSE, NULL);
INSERT INTO ABSENCE (USER_ID, START_DATE, END_DATE, TYPE, ALL_DAY, COMMENT)
VALUES ((SELECT ID FROM USERX WHERE USERNAME = 'emp3'), '2026-04-28T08:00:00+02:00', '2026-05-02T18:00:00+02:00', 'VACATION', FALSE, 'Long weekend trip');

-- Extra employees
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE) VALUES
(TRUE, 'Julia',   'Mayr',   '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp4',  (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Stefan',  'Krenn',  '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp5',  (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Petra',   'Hofer',  '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp6',  (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Lukas',   'Eder',   '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp7',  (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Sophie',  'Bauer',  '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp8',  (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Michael', 'Lang',   '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp9',  (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Hannah',  'Wolf',   '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp10', (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Felix',   'Stern',  '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'emp11', (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00');

INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES
((SELECT ID FROM USERX WHERE USERNAME = 'emp4'),  'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp5'),  'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp6'),  'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp7'),  'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp8'),  'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp9'),  'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp10'), 'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'emp11'), 'EMPLOYEE');

UPDATE USERX SET DEPARTMENT_ID = (SELECT ID FROM DEPARTMENT WHERE NAME = 'Engineering')
WHERE USERNAME IN ('emp4', 'emp5', 'emp6', 'emp7', 'emp8', 'emp9');
UPDATE USERX SET DEPARTMENT_ID = (SELECT ID FROM DEPARTMENT WHERE NAME = 'Human Resources')
WHERE USERNAME IN ('emp10', 'emp11');

INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES
(2000, (SELECT ID FROM USERX WHERE USERNAME = 'emp4')),
(2000, (SELECT ID FROM USERX WHERE USERNAME = 'emp5'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES
(2200, (SELECT ID FROM USERX WHERE USERNAME = 'emp6')),
(2200, (SELECT ID FROM USERX WHERE USERNAME = 'emp7')),
(2200, (SELECT ID FROM USERX WHERE USERNAME = 'emp8')),
(2200, (SELECT ID FROM USERX WHERE USERNAME = 'emp9'));
INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES
(3000, (SELECT ID FROM USERX WHERE USERNAME = 'emp10')),
(3000, (SELECT ID FROM USERX WHERE USERNAME = 'emp11'));

-- Raspberry Pis
INSERT INTO raspberry_pi (id, generated_device_id, status, last_seen, room_id, ip_address) VALUES
(10001, 'd3bugrpi-dbug-t3st-dbug-dbgr4spb3rry', 'ONLINE',  NOW() - INTERVAL '2 minutes',  1000, '192.168.1.100'),
(10002, 'rpi-eng-office',                        'ONLINE',  NOW() - INTERVAL '1 minutes',  2000, '192.168.1.102'),
(10003, 'rpi-hr-satellite',                      'ONLINE',  NOW() - INTERVAL '3 minutes',  2100, '192.168.1.103'),
(10004, 'rpi-eng-lab',                           'ONLINE',  NOW() - INTERVAL '1 minutes',  2200, '192.168.1.104'),
(10005, 'rpi-meeting-a2',                        'OFFLINE', NOW() - INTERVAL '2 days',     2300, '192.168.1.105'),
(10006, 'rpi-hr-main',                           'ONLINE',  NOW() - INTERVAL '2 minutes',  3000, '192.168.1.106'),
(10007, 'rpi-reception-b1',                      'ONLINE',  NOW() - INTERVAL '4 minutes',  3100, '192.168.1.107');

-- Sensor Stations
INSERT INTO sensor_station (id, generated_device_id, status, mode, raspberry_pi_id) VALUES
(20001, 'ss-lobby-a1',     'ONLINE',  'REGULAR', 10001),
(20002, 'ss-eng-office',   'ONLINE',  'REGULAR', 10002),
(20003, 'ss-hr-satellite', 'ONLINE',  'REGULAR', 10003),
(20004, 'ss-eng-lab',      'ONLINE',  'REGULAR', 10004),
(20005, 'ss-meeting-a2',   'OFFLINE', 'REGULAR', 10005),
(20006, 'ss-hr-main',      'ONLINE',  'REGULAR', 10006),
(20007, 'ss-reception-b1', 'ONLINE',  'REGULAR', 10007);

-- Sensors
INSERT INTO sensor (id, type, sensor_station_id) VALUES
(30001, 'TEMPERATURE', 20001), (30002, 'HUMIDITY', 20001), (30003, 'AIR_QUALITY', 20001), (30004, 'PRESSURE', 20001),
(30011, 'TEMPERATURE', 20002), (30012, 'HUMIDITY', 20002), (30013, 'AIR_QUALITY', 20002), (30014, 'PRESSURE', 20002),
(30021, 'TEMPERATURE', 20003), (30022, 'HUMIDITY', 20003), (30023, 'AIR_QUALITY', 20003), (30024, 'PRESSURE', 20003),
(30031, 'TEMPERATURE', 20004), (30032, 'HUMIDITY', 20004), (30033, 'AIR_QUALITY', 20004), (30034, 'PRESSURE', 20004),
(30041, 'TEMPERATURE', 20005), (30042, 'HUMIDITY', 20005), (30043, 'AIR_QUALITY', 20005), (30044, 'PRESSURE', 20005),
(30051, 'TEMPERATURE', 20006), (30052, 'HUMIDITY', 20006), (30053, 'AIR_QUALITY', 20006), (30054, 'PRESSURE', 20006),
(30061, 'TEMPERATURE', 20007), (30062, 'HUMIDITY', 20007), (30063, 'AIR_QUALITY', 20007), (30064, 'PRESSURE', 20007);

-- Thresholds
INSERT INTO threshold (id, room_id, sensor_type, upper_limit, lower_limit, updated_at) VALUES
(40001, 1000, 'TEMPERATURE', 26.0, 16.0, NOW()), (40002, 1000, 'HUMIDITY', 65.0, 25.0, NOW()), (40003, 1000, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40004, 1000, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40011, 2000, 'TEMPERATURE', 26.0, 16.0, NOW()), (40012, 2000, 'HUMIDITY', 65.0, 25.0, NOW()), (40013, 2000, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40014, 2000, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40021, 2100, 'TEMPERATURE', 26.0, 16.0, NOW()), (40022, 2100, 'HUMIDITY', 65.0, 25.0, NOW()), (40023, 2100, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40024, 2100, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40031, 2200, 'TEMPERATURE', 26.0, 16.0, NOW()), (40032, 2200, 'HUMIDITY', 65.0, 25.0, NOW()), (40033, 2200, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40034, 2200, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40041, 2300, 'TEMPERATURE', 26.0, 16.0, NOW()), (40042, 2300, 'HUMIDITY', 65.0, 25.0, NOW()), (40043, 2300, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40044, 2300, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40051, 3000, 'TEMPERATURE', 26.0, 16.0, NOW()), (40052, 3000, 'HUMIDITY', 65.0, 25.0, NOW()), (40053, 3000, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40054, 3000, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40061, 3100, 'TEMPERATURE', 26.0, 16.0, NOW()), (40062, 3100, 'HUMIDITY', 65.0, 25.0, NOW()), (40063, 3100, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40064, 3100, 'PRESSURE', 103000.0, 92000.0, NOW());

-- Bulk historical measurements (30 days x hourly) using generate_series
-- Lobby A1
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30001, ROUND(CAST(18.5 + 1.5 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.6 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30002, ROUND(CAST(55.0 - 6.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 3.0 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30003, ROUND(CAST(420.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 18 THEN 280.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 10.0) ELSE 0 END + (RANDOM() - 0.5) * 50.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30004, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Engineering Office
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30011, ROUND(CAST(21.5 + 2.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.8 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30012, ROUND(CAST(52.0 - 5.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 2.5 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30013, ROUND(CAST(430.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 18 THEN 380.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 10.0) ELSE 0 END + (RANDOM() - 0.5) * 55.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30014, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- HR Satellite A1
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30021, ROUND(CAST(21.0 + 2.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.7 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30022, ROUND(CAST(53.0 - 5.5 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 2.5 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30023, ROUND(CAST(420.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 18 THEN 340.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 10.0) ELSE 0 END + (RANDOM() - 0.5) * 50.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30024, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Engineering Lab
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30031, ROUND(CAST(22.5 + 2.5 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.8 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30032, ROUND(CAST(48.0 - 6.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 2.0 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30033, ROUND(CAST(440.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 9 AND 19 THEN 410.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 9) * PI() / 10.0) ELSE 0 END + (RANDOM() - 0.5) * 60.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30034, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Meeting Room A2
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30041, ROUND(CAST(20.0 + 2.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.8 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30042, ROUND(CAST(54.0 - 6.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 3.0 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30043, ROUND(CAST(415.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 9 AND 16 THEN 250.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 9) * PI() / 7.0) ELSE 0 END + (RANDOM() - 0.5) * 50.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30044, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- HR Main Office
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30051, ROUND(CAST(21.5 + 2.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.7 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30052, ROUND(CAST(53.0 - 5.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 2.0 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30053, ROUND(CAST(425.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 17 THEN 360.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 9.0) ELSE 0 END + (RANDOM() - 0.5) * 55.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30054, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Reception B1
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30061, ROUND(CAST(19.0 + 2.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 1.2 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30062, ROUND(CAST(56.0 - 5.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 3.5 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30063, ROUND(CAST(410.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 17 THEN 160.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 9.0) ELSE 0 END + (RANDOM() - 0.5) * 40.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30064, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Violation scenario measurements
-- Scenario 1: Engineering Lab overheating
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30031, 26.8, 'CELSIUS', NOW() - INTERVAL '4 hours'),
(30031, 27.1, 'CELSIUS', NOW() - INTERVAL '3 hours'),
(30031, 27.4, 'CELSIUS', NOW() - INTERVAL '2 hours'),
(30031, 27.2, 'CELSIUS', NOW() - INTERVAL '1 hours');

-- Scenario 2: Meeting Room A2 CO2 spike 10 days ago
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30043, 1050.0, 'PPM', NOW() - INTERVAL '10 days' + INTERVAL '10 hours'),
(30043, 1180.0, 'PPM', NOW() - INTERVAL '10 days' + INTERVAL '11 hours'),
(30043, 1290.0, 'PPM', NOW() - INTERVAL '10 days' + INTERVAL '12 hours'),
(30043, 1340.0, 'PPM', NOW() - INTERVAL '10 days' + INTERVAL '13 hours'),
(30043, 1210.0, 'PPM', NOW() - INTERVAL '10 days' + INTERVAL '14 hours'),
(30043,  970.0, 'PPM', NOW() - INTERVAL '10 days' + INTERVAL '15 hours');

-- Scenario 3: Reception B1 humidity high
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30062, 67.3, 'PERCENTAGE', NOW() - INTERVAL '3 hours'),
(30062, 68.9, 'PERCENTAGE', NOW() - INTERVAL '2 hours'),
(30062, 69.4, 'PERCENTAGE', NOW() - INTERVAL '1 hours');

-- Scenario 4: HR Main Office cold snap 14 days ago
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30051, 15.8, 'CELSIUS', NOW() - INTERVAL '14 days' + INTERVAL '7 hours'),
(30051, 15.2, 'CELSIUS', NOW() - INTERVAL '14 days' + INTERVAL '8 hours'),
(30051, 14.9, 'CELSIUS', NOW() - INTERVAL '14 days' + INTERVAL '9 hours'),
(30051, 15.1, 'CELSIUS', NOW() - INTERVAL '14 days' + INTERVAL '10 hours'),
(30051, 15.6, 'CELSIUS', NOW() - INTERVAL '14 days' + INTERVAL '11 hours');

-- Violations
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40031, 'UPPER', NOW() - INTERVAL '4 hours', NULL, TRUE
FROM measurement m WHERE m.sensor_id = 30031 AND m.measured_value = 26.8
  AND m.measured_at BETWEEN NOW() - INTERVAL '5 hours' AND NOW() - INTERVAL '210 minutes' LIMIT 1;

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40043, 'UPPER', NOW() - INTERVAL '10 days' + INTERVAL '10 hours', NOW() - INTERVAL '10 days' + INTERVAL '16 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30043 AND m.measured_value = 1050.0
  AND m.measured_at BETWEEN NOW() - INTERVAL '11 days' AND NOW() - INTERVAL '9 days' LIMIT 1;

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40062, 'UPPER', NOW() - INTERVAL '3 hours', NULL, TRUE
FROM measurement m WHERE m.sensor_id = 30062 AND m.measured_value = 67.3
  AND m.measured_at BETWEEN NOW() - INTERVAL '4 hours' AND NOW() - INTERVAL '150 minutes' LIMIT 1;

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40051, 'LOWER', NOW() - INTERVAL '14 days' + INTERVAL '7 hours', NOW() - INTERVAL '14 days' + INTERVAL '13 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30051 AND m.measured_value = 15.8
  AND m.measured_at BETWEEN NOW() - INTERVAL '15 days' AND NOW() - INTERVAL '13 days' LIMIT 1;

-- SuperAdmin debug data — Building C (Operations dept)
INSERT INTO USERX (ENABLED, FIRST_NAME, LAST_NAME, PASSWORD, USERNAME, CREATE_USER_ID, CREATE_DATE) VALUES
(TRUE, 'Claire', 'Douglas', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'ops_emp1', (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00'),
(TRUE, 'Noah',   'Fischer', '{bcrypt}$2b$12$gimw81jnsxtcHMBRe6LVe.NZCPf3G2ugUyKqcYwJRlJuN6ubTXkNS', 'ops_emp2', (SELECT ID FROM USERX WHERE USERNAME = 'admin'), '2024-01-01 00:00:00');

INSERT INTO USERX_USERX_ROLE (USERX_ID, ROLES) VALUES
((SELECT ID FROM USERX WHERE USERNAME = 'ops_emp1'), 'EMPLOYEE'),
((SELECT ID FROM USERX WHERE USERNAME = 'ops_emp2'), 'EMPLOYEE');

INSERT INTO DEPARTMENT (NAME, DEPARTMENT_HEAD_ID)
VALUES ('Operations', (SELECT ID FROM USERX WHERE USERNAME = 'superadmin'));

UPDATE USERX SET DEPARTMENT_ID = (SELECT ID FROM DEPARTMENT WHERE NAME = 'Operations')
WHERE USERNAME IN ('superadmin', 'ops_emp1', 'ops_emp2');

INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (4000, 'Ops Lounge C1', 3000, 1, 20, 20, 200, 120);
INSERT INTO COMMON_SPACE (ID) VALUES (4000);
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (5000, 'Operations Hub', 3000, 1, 240, 20, 280, 150);
INSERT INTO OFFICE_SPACE (ID, MIN_OCCUPANCY) VALUES (5000, 3);
INSERT INTO ROOM (ID, NAME, BUILDING_ID, FLOOR, CANVAS_X, CANVAS_Y, CANVAS_WIDTH, CANVAS_HEIGHT) VALUES (5100, 'Server Room C1', 3000, 1, 540, 20, 200, 150);
INSERT INTO OFFICE_SPACE (ID, MIN_OCCUPANCY) VALUES (5100, 1);

INSERT INTO OFFICE_SPACE_USERS (OFFICE_SPACE_ID, USER_ID) VALUES
(5000, (SELECT ID FROM USERX WHERE USERNAME = 'superadmin')),
(5000, (SELECT ID FROM USERX WHERE USERNAME = 'ops_emp1')),
(5000, (SELECT ID FROM USERX WHERE USERNAME = 'ops_emp2')),
(5100, (SELECT ID FROM USERX WHERE USERNAME = 'ops_emp1'));

INSERT INTO ABSENCE (USER_ID, START_DATE, END_DATE, TYPE, ALL_DAY, COMMENT) VALUES
((SELECT ID FROM USERX WHERE USERNAME = 'superadmin'), CURRENT_DATE + INTERVAL '7 days',  CURRENT_DATE + INTERVAL '14 days', 'VACATION', TRUE, 'Summer break'),
((SELECT ID FROM USERX WHERE USERNAME = 'ops_emp1'),   CURRENT_DATE - INTERVAL '1 days',  CURRENT_DATE + INTERVAL '2 days',  'SICK',     TRUE, 'Flu'),
((SELECT ID FROM USERX WHERE USERNAME = 'ops_emp2'),   CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE + INTERVAL '60 days', 'PARENTAL', TRUE, 'Parental leave');

INSERT INTO raspberry_pi (id, generated_device_id, status, last_seen, room_id, ip_address) VALUES
(10008, 'rpi-ops-lounge',  'ONLINE', NOW() - INTERVAL '1 minutes', 4000, '192.168.1.108'),
(10009, 'rpi-ops-hub',     'ONLINE', NOW() - INTERVAL '2 minutes', 5000, '192.168.1.109'),
(10010, 'rpi-server-room', 'ONLINE', NOW() - INTERVAL '1 minutes', 5100, '192.168.1.110');

INSERT INTO sensor_station (id, generated_device_id, status, mode, raspberry_pi_id) VALUES
(20008, 'ss-ops-lounge',  'ONLINE', 'REGULAR', 10008),
(20009, 'ss-ops-hub',     'ONLINE', 'REGULAR', 10009),
(20010, 'ss-server-room', 'ONLINE', 'REGULAR', 10010);

INSERT INTO sensor (id, type, sensor_station_id) VALUES
(30065, 'TEMPERATURE', 20008), (30066, 'HUMIDITY', 20008), (30067, 'AIR_QUALITY', 20008), (30068, 'PRESSURE', 20008),
(30075, 'TEMPERATURE', 20009), (30076, 'HUMIDITY', 20009), (30077, 'AIR_QUALITY', 20009), (30078, 'PRESSURE', 20009),
(30085, 'TEMPERATURE', 20010), (30086, 'HUMIDITY', 20010), (30087, 'AIR_QUALITY', 20010), (30088, 'PRESSURE', 20010);

INSERT INTO threshold (id, room_id, sensor_type, upper_limit, lower_limit, updated_at) VALUES
(40065, 4000, 'TEMPERATURE', 26.0, 16.0, NOW()), (40066, 4000, 'HUMIDITY', 65.0, 25.0, NOW()), (40067, 4000, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40068, 4000, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40075, 5000, 'TEMPERATURE', 26.0, 16.0, NOW()), (40076, 5000, 'HUMIDITY', 65.0, 25.0, NOW()), (40077, 5000, 'AIR_QUALITY', 1000.0, NULL, NOW()), (40078, 5000, 'PRESSURE', 103000.0, 92000.0, NOW()),
(40085, 5100, 'TEMPERATURE', 24.0, 16.0, NOW()), (40086, 5100, 'HUMIDITY', 55.0, 20.0, NOW()), (40087, 5100, 'AIR_QUALITY', 800.0, NULL, NOW()),  (40088, 5100, 'PRESSURE', 103000.0, 92000.0, NOW());

-- Ops Lounge C1
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30065, ROUND(CAST(19.5 + 1.8 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.7 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30066, ROUND(CAST(56.0 - 5.5 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 2.5 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30067, ROUND(CAST(415.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 17 THEN 240.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 9.0) ELSE 0 END + (RANDOM() - 0.5) * 45.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30068, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Operations Hub
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30075, ROUND(CAST(21.0 + 2.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.8 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30076, ROUND(CAST(51.0 - 5.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 2.0 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30077, ROUND(CAST(430.0 + CASE WHEN EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) BETWEEN 8 AND 18 THEN 370.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 10.0) ELSE 0 END + (RANDOM() - 0.5) * 50.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30078, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Server Room C1
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30085, ROUND(CAST(23.5 + 0.8 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 0.5 AS numeric), 1), 'CELSIUS', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30086, ROUND(CAST(38.0 - 3.0 * SIN((EXTRACT(HOUR FROM NOW() - INTERVAL '1 hour' * (720 - x)) - 8) * PI() / 12.0) + (RANDOM() - 0.5) * 1.5 AS numeric), 1), 'PERCENTAGE', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30087, ROUND(CAST(420.0 + (RANDOM() - 0.5) * 30.0 AS numeric), 0), 'PPM', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

INSERT INTO measurement (sensor_id, measured_value, unit, measured_at)
SELECT 30088, ROUND(CAST(97800.0 + 600.0 * SIN(EXTRACT(DOY FROM NOW() - INTERVAL '1 hour' * (720 - x)) * 2 * PI() / 365.0) + (RANDOM() - 0.5) * 80.0 AS numeric), 0), 'PASCAL', NOW() - INTERVAL '1 hour' * (720 - x)
FROM generate_series(0, 718) AS t(x);

-- Server Room C1 active violation
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 24.3, 'CELSIUS', NOW() - INTERVAL '5 hours'),
(30085, 24.7, 'CELSIUS', NOW() - INTERVAL '4 hours'),
(30085, 25.1, 'CELSIUS', NOW() - INTERVAL '3 hours'),
(30085, 25.4, 'CELSIUS', NOW() - INTERVAL '2 hours'),
(30085, 25.2, 'CELSIUS', NOW() - INTERVAL '1 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', NOW() - INTERVAL '5 hours', NULL, TRUE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 24.3
  AND m.measured_at BETWEEN NOW() - INTERVAL '6 hours' AND NOW() - INTERVAL '4 hours' LIMIT 1;

-- Historical violations for Operations dept
-- April 2026
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 24.61, 'CELSIUS',    NOW() - INTERVAL '22 days' + INTERVAL '9 hours'),
(30075, 26.21, 'CELSIUS',    NOW() - INTERVAL '18 days' + INTERVAL '14 hours'),
(30066, 65.21, 'PERCENTAGE', NOW() - INTERVAL '15 days' + INTERVAL '11 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '3 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 24.61 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40075, 'UPPER', m.measured_at, m.measured_at + INTERVAL '2 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30075 AND m.measured_value = 26.21 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40066, 'UPPER', m.measured_at, m.measured_at + INTERVAL '4 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30066 AND m.measured_value = 65.21 LIMIT 1;

-- March 2026
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 24.82, 'CELSIUS', NOW() - INTERVAL '52 days' + INTERVAL '10 hours'),
(30077, 1045,  'PPM',     NOW() - INTERVAL '47 days' + INTERVAL '13 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '5 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 24.82 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40077, 'UPPER', m.measured_at, m.measured_at + INTERVAL '2 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30077 AND m.measured_value = 1045 LIMIT 1;

-- February 2026
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 24.91, 'CELSIUS',    NOW() - INTERVAL '81 days' + INTERVAL '8 hours'),
(30085, 25.14, 'CELSIUS',    NOW() - INTERVAL '75 days' + INTERVAL '10 hours'),
(30076, 65.51, 'PERCENTAGE', NOW() - INTERVAL '78 days' + INTERVAL '14 hours'),
(30067, 1062,  'PPM',        NOW() - INTERVAL '72 days' + INTERVAL '12 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '4 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 24.91 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '3 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 25.14 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40076, 'UPPER', m.measured_at, m.measured_at + INTERVAL '6 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30076 AND m.measured_value = 65.51 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40067, 'UPPER', m.measured_at, m.measured_at + INTERVAL '2 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30067 AND m.measured_value = 1062 LIMIT 1;

-- January 2026
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 25.34, 'CELSIUS', NOW() - INTERVAL '111 days' + INTERVAL '9 hours'),
(30065, 26.34, 'CELSIUS', NOW() - INTERVAL '105 days' + INTERVAL '11 hours'),
(30075, 26.43, 'CELSIUS', NOW() - INTERVAL '100 days' + INTERVAL '15 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '4 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 25.34 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40065, 'UPPER', m.measured_at, m.measured_at + INTERVAL '3 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30065 AND m.measured_value = 26.34 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40075, 'UPPER', m.measured_at, m.measured_at + INTERVAL '2 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30075 AND m.measured_value = 26.43 LIMIT 1;

-- December 2025
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 24.71, 'CELSIUS',    NOW() - INTERVAL '142 days' + INTERVAL '10 hours'),
(30086, 55.81, 'PERCENTAGE', NOW() - INTERVAL '135 days' + INTERVAL '14 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '5 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 24.71 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40086, 'UPPER', m.measured_at, m.measured_at + INTERVAL '3 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30086 AND m.measured_value = 55.81 LIMIT 1;

-- November 2025
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30085, 25.11, 'CELSIUS', NOW() - INTERVAL '172 days' + INTERVAL '8 hours'),
(30067, 1055,  'PPM',     NOW() - INTERVAL '165 days' + INTERVAL '13 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40085, 'UPPER', m.measured_at, m.measured_at + INTERVAL '4 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30085 AND m.measured_value = 25.11 LIMIT 1;
INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40067, 'UPPER', m.measured_at, m.measured_at + INTERVAL '2 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30067 AND m.measured_value = 1055 LIMIT 1;

-- October 2025
INSERT INTO measurement (sensor_id, measured_value, unit, measured_at) VALUES
(30075, 26.71, 'CELSIUS', NOW() - INTERVAL '202 days' + INTERVAL '11 hours');

INSERT INTO violation (measurement_id, threshold_id, violation_type, recorded_at, end_time, active)
SELECT m.id, 40075, 'UPPER', m.measured_at, m.measured_at + INTERVAL '3 hours', FALSE
FROM measurement m WHERE m.sensor_id = 30075 AND m.measured_value = 26.71 LIMIT 1;

-- Reset sequences (PostgreSQL uses named sequences)
-- NOTE: Adjust sequence names below to match your actual Hibernate-generated sequence names.
-- Common patterns: table_id_seq or hibernate_sequence. Check with \ds in psql.
SELECT setval(pg_get_serial_sequence('raspberry_pi',   'id'), 10011);
SELECT setval(pg_get_serial_sequence('sensor_station', 'id'), 20011);
SELECT setval(pg_get_serial_sequence('sensor',         'id'), 30089);
SELECT setval(pg_get_serial_sequence('threshold',      'id'), 40089);

-- Create index on measurement for faster queries by sensor and timestamp (descending for recent first)
CREATE INDEX idx_measurement_sensor_timestamp
ON measurement(sensor_id, measured_at DESC);
