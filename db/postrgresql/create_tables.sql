
CREATE SEQUENCE <<<<SCHEMA>>>>.dns_id MINVALUE 0\g

CREATE TABLE <<<<SCHEMA>>>>.dns
(
	id INTEGER DEFAULT nextval('<<<<SCHEMA>>>>.dns_id') PRIMARY KEY,
	datetime TIMESTAMP,
	client_ip VARCHAR(39),	   -- max length of an IPv6 (colon separated)
	query_domain VARCHAR(120), -- hoping there are no domains longer ...
	response_zone VARCHAR(120) -- hoping there are no domains longer ...
)\g

CREATE SEQUENCE <<<<SCHEMA>>>>.web_id MINVALUE 0\g

CREATE TABLE <<<<SCHEMA>>>>.web
(
	id INTEGER DEFAULT nextval('<<<<SCHEMA>>>>.web_id') PRIMARY KEY,
	datetime TIMESTAMP,
	client_ip VARCHAR(39),	    -- max length of an IPv6 (colon separated)
	client_hostname VARCHAR(80),-- hoping there are no hostnames longer ...
	query_domain VARCHAR(120) -- hoping there are no domains longer ...
)\g


