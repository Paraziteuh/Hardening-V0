# create DBs
create database if not exists sqli_db;
create database if not exists idor_db;

# create users
create user 'sqli_user'@'%' identified by '609cd9eecebfb63ba1c2';
create user 'idor_user'@'%' identified by '0a04ffebd4186d8cc7f1';

# grant privileges
grant all privileges on sqli_db.* to 'sqli_user'@'%';
grant all privileges on idor_db.* to 'idor_user'@'%';
flush privileges;

# drop tables if exists
DROP TABLE IF EXISTS sqli_db.users;
DROP TABLE IF EXISTS idor_db.mailbox;
DROP TABLE IF EXISTS idor_db.messages;
DROP TABLE IF EXISTS idor_db.users;

# create tables
CREATE TABLE sqli_db.users (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `nickname` varchar(64) DEFAULT NULL,
  `password` varchar(68) DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL,
  `comments` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=latin1;

CREATE TABLE idor_db.users (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `login` varchar(64) DEFAULT NULL,
  `password` varchar(68) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=latin1;

CREATE TABLE idor_db.messages (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `content` varchar(255) DEFAULT NULL,
  `title` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=latin1;

CREATE TABLE idor_db.mailbox (
  `id_user` int(11) NOT NULL,
  `id_message` int(11) NOT NULL,
  PRIMARY KEY (`id_user`,`id_message`),
  KEY `id_message` (`id_message`),
  CONSTRAINT `mailbox_ibfk_1` FOREIGN KEY (`id_user`) REFERENCES idor_db.users (`id`),
  CONSTRAINT `mailbox_ibfk_2` FOREIGN KEY (`id_message`) REFERENCES idor_db.messages (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

# insert data
INSERT INTO sqli_db.users VALUES (1,'admin','ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f','LYON','Administrateur du site'),(2,'pueblo','a20aff106fe011d5dd696e3b7105200ff74331eeb8e865bb80ebd82b12665a07','PARIS','Utilisateur'),(3,'mcdonalds','5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',NULL,NULL);

INSERT INTO idor_db.users VALUES (1,'admin','ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f'),(2,'user','a20aff106fe011d5dd696e3b7105200ff74331eeb8e865bb80ebd82b12665a07');

INSERT INTO idor_db.messages VALUES (1,'hello admin, this is your password : password123','hello admin'),(2,'hello user, this is your password : password321','hello user'),(3,'Welcome on your mailbox platform','welcome new user'),(4,'Hey admin, welcome on your secure mailbox service','hey admin !');

INSERT INTO idor_db.mailbox VALUES (1,1),(2,2),(2,3),(1,4);
