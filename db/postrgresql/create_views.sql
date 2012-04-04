/*
 *  The views are a heirarchy of summaries of the data
 *
 * (dns|web)_(day|week|month)
 *
 * provide a time limited view of the data
 *
 * (dns|web)_(day|week|month)_all
 *
 * provide the same, but exclude the id column
 *
 * (dns|web)_(day|week|month)_frequency
 *
 * SELECT data in the period AND GROUP BY the client_ip to show
 * how many connections there have been by each client.
 *
 */
CREATE VIEW <<<<SCHEMA>>>>.dns_day AS 
	SELECT * FROM <<<<SCHEMA>>>>.dns WHERE date(now()) - date(datetime) <= 1;
CREATE VIEW <<<<SCHEMA>>>>.dns_week AS 
	SELECT * FROM <<<<SCHEMA>>>>.dns WHERE date(now()) - date(datetime) <= 7;
CREATE VIEW <<<<SCHEMA>>>>.dns_month AS 
	SELECT * FROM <<<<SCHEMA>>>>.dns WHERE date(now()) - date(datetime) <= 30;

CREATE VIEW <<<<SCHEMA>>>>.dns_day_trunc AS
	SELECT  date_trunc('day', datetime), count(datetime), 
		client_ip, query_domain, response_zone
	FROM <<<<SCHEMA>>>>.dns_day
	GROUP BY date_trunc('day', datetime), client_ip, query_domain, response_zone
	ORDER BY date_trunc('day', datetime) DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_week_trunc AS
	SELECT  date_trunc('week', datetime), count(datetime), 
		client_ip, query_domain, response_zone
	FROM <<<<SCHEMA>>>>.dns_week
	GROUP BY date_trunc('week', datetime), client_ip, query_domain, response_zone
	ORDER BY date_trunc('week', datetime) DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_month_trunc AS
	SELECT  date_trunc('month', datetime), count(datetime), 
		client_ip, query_domain, response_zone
	FROM <<<<SCHEMA>>>>.dns_month 
	GROUP BY date_trunc('month', datetime), client_ip, query_domain, response_zone
	ORDER BY date_trunc('month', datetime) DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_day_frequency AS
	SELECT min(datetime) as "min(datetime)", count(*), client_ip 
	FROM <<<<SCHEMA>>>>.dns_day
	GROUP BY client_ip
	ORDER BY count(*) DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_week_frequency AS
	SELECT min(datetime) as "min(datetime)", count(*), client_ip 
	FROM <<<<SCHEMA>>>>.dns_week
	GROUP BY client_ip
	ORDER BY count(*) DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_month_frequency AS
	SELECT min(datetime) as "min(datetime)", count(*), client_ip 
	FROM <<<<SCHEMA>>>>.dns_month
	GROUP BY client_ip
	ORDER BY count(*) DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_day_all AS
	SELECT datetime, client_ip, query_domain, response_zone 
	FROM <<<<SCHEMA>>>>.dns_day
	ORDER BY datetime DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_week_all AS
	SELECT datetime, client_ip, query_domain, response_zone 
	FROM <<<<SCHEMA>>>>.dns_week
	ORDER BY datetime DESC;

CREATE VIEW <<<<SCHEMA>>>>.dns_month_all AS
	SELECT datetime, client_ip, query_domain, response_zone 
	FROM <<<<SCHEMA>>>>.dns_month
	ORDER BY datetime DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_day AS 
	SELECT * 
	FROM <<<<SCHEMA>>>>.web 
	WHERE date(now()) - date(datetime) <= 1;

CREATE VIEW <<<<SCHEMA>>>>.web_week AS 
	SELECT * 
	FROM <<<<SCHEMA>>>>.web 
	WHERE date(now()) - date(datetime) <= 7;

CREATE VIEW <<<<SCHEMA>>>>.web_month AS 
	SELECT * 
	FROM <<<<SCHEMA>>>>.web 
	WHERE date(now()) - date(datetime) <= 30;

CREATE VIEW <<<<SCHEMA>>>>.web_day_trunc AS
	SELECT  date_trunc('day', datetime), count(datetime), 
		client_ip, client_hostname, query_domain
	FROM <<<<SCHEMA>>>>.web_day
	GROUP BY date_trunc('day', datetime), client_ip, 
		client_hostname, query_domain
	ORDER BY date_trunc('day', datetime) DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_week_trunc AS
	SELECT  date_trunc('week', datetime), count(datetime), 
		client_ip, client_hostname, query_domain
	FROM <<<<SCHEMA>>>>.web_week
	GROUP BY date_trunc('week', datetime), client_ip, 
		client_hostname, query_domain
	ORDER BY date_trunc('week', datetime) DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_month_trunc AS
	SELECT  date_trunc('month', datetime), count(datetime), 
		client_ip, client_hostname, query_domain
	FROM <<<<SCHEMA>>>>.web_month
	GROUP BY date_trunc('month', datetime), client_ip, 
		client_hostname, query_domain
	ORDER BY date_trunc('month', datetime) DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_day_frequency AS
	SELECT min(datetime) as "min(datetime)", count(*), 
		client_hostname, client_ip
	FROM <<<<SCHEMA>>>>.web_day
	GROUP BY client_hostname, client_ip
	ORDER BY count(*), client_hostname, client_ip DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_week_frequency AS
	SELECT min(datetime) as "min(datetime)", count(*), 
		client_hostname, client_ip
	FROM <<<<SCHEMA>>>>.web_week
	GROUP BY client_hostname, client_ip
	ORDER BY count(*), client_hostname, client_ip DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_month_frequency AS
	SELECT min(datetime) as "min(datetime)", count(*),
		client_hostname, client_ip
	FROM <<<<SCHEMA>>>>.web_month
	GROUP BY client_hostname, client_ip
	ORDER BY count(*), client_hostname, client_ip DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_day_all AS
	SELECT datetime, client_hostname, client_ip, query_domain 
	FROM <<<<SCHEMA>>>>.web_day
	ORDER BY datetime DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_week_all AS
	SELECT datetime, client_hostname, client_ip, query_domain 
	FROM <<<<SCHEMA>>>>.web_week
	ORDER BY datetime DESC;

CREATE VIEW <<<<SCHEMA>>>>.web_month_all AS
	SELECT datetime, client_hostname, client_ip, query_domain 
	FROM <<<<SCHEMA>>>>.web_month
	ORDER BY datetime DESC;

/*
 * Correlated data: matches between dns AND web (data grouped into 'buckets'
 * of time by use of the _trunc views).
 */
CREATE VIEW <<<<SCHEMA>>>>.cor_day_web AS
	SELECT d.date_trunc, d.count, d.client_ip, 
		w.client_hostname, d.query_domain
	FROM <<<<SCHEMA>>>>.dns_day_trunc d, <<<<SCHEMA>>>>.web_day_trunc w
	WHERE d.date_trunc = w.date_trunc AND
		d.client_ip = w.client_ip AND
		d.query_domain = w.query_domain
	GROUP BY d.date_trunc, d.count, d.client_ip, 
		w.client_hostname, d.query_domain
	ORDER BY d.date_trunc DESC, d.count DESC;

CREATE VIEW <<<<SCHEMA>>>>.cor_week_web AS
	SELECT d.date_trunc, d.count, d.client_ip, 
		w.client_hostname, d.query_domain
	FROM <<<<SCHEMA>>>>.dns_week_trunc d, <<<<SCHEMA>>>>.web_week_trunc w
	WHERE d.date_trunc = w.date_trunc AND
		d.client_ip = w.client_ip AND
		d.query_domain = w.query_domain
	GROUP BY d.date_trunc, d.count, d.client_ip, 
		w.client_hostname, d.query_domain
	ORDER BY d.date_trunc DESC, d.count DESC;

CREATE VIEW <<<<SCHEMA>>>>.cor_month_web AS
	SELECT d.date_trunc, d.count, d.client_ip, 
		w.client_hostname, d.query_domain
	FROM <<<<SCHEMA>>>>.dns_month_trunc d, <<<<SCHEMA>>>>.web_month_trunc w
	WHERE d.date_trunc = w.date_trunc AND
		d.client_ip = w.client_ip AND
		d.query_domain = w.query_domain
	GROUP BY d.date_trunc, d.count, d.client_ip, 
		w.client_hostname, d.query_domain
	ORDER BY d.date_trunc DESC, d.count DESC;

/*
 * Not correlated: dns record but no matching web record
 */

CREATE VIEW <<<<SCHEMA>>>>.cor_day_dns AS
	SELECT d.date_trunc, d.count, d.client_ip, 
		d.query_domain, d.response_zone
	FROM <<<<SCHEMA>>>>.dns_day_trunc d 
	WHERE not exists
	( 
		SELECT 1 
		FROM <<<<SCHEMA>>>>.web_day_trunc w
		WHERE d.date_trunc = w.date_trunc AND 
			d.client_ip = w.client_ip AND 
			d.query_domain = w.query_domain
	) 
	ORDER BY d.date_trunc DESC, d.count DESC, d.client_ip DESC;

CREATE VIEW <<<<SCHEMA>>>>.cor_week_dns AS
	SELECT d.date_trunc, d.count, 
		d.client_ip, d.query_domain, d.response_zone
	FROM <<<<SCHEMA>>>>.dns_week_trunc d 
	WHERE not exists
	( 
		SELECT 1 
		FROM <<<<SCHEMA>>>>.web_week_trunc w
		WHERE d.date_trunc = w.date_trunc AND 
			d.client_ip = w.client_ip AND 
			d.query_domain = w.query_domain
	) 
	ORDER BY d.date_trunc DESC, d.count DESC, d.client_ip DESC;

CREATE VIEW <<<<SCHEMA>>>>.cor_month_dns AS
	SELECT d.date_trunc, d.count, 
		d.client_ip, d.query_domain, d.response_zone
	FROM <<<<SCHEMA>>>>.dns_month_trunc d 
	WHERE not exists
	( 
		SELECT 1 
		FROM <<<<SCHEMA>>>>.web_month_trunc w
		WHERE d.date_trunc = w.date_trunc AND 
			d.client_ip = w.client_ip AND 
			d.query_domain = w.query_domain
	) 
	ORDER BY d.date_trunc DESC, d.count DESC, d.client_ip DESC;

