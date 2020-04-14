/***
* Name: Dbtest
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model Dbtest

global {
	map<string, string> MySQL_params<- ['host'::'localhost', 'dbtype'::'MySQL', 'database'::'gtfs_toulouse', 'port'::'3306', 'user'::'root', 'passwd'::''];
	
	init {
		write "This model will work only if the corresponding database is installed and the database management server launched." color: #red;

		create DB_accessor;
	}

}

species DB_accessor skills: [SQLSKILL] {
	list listRes <- [];
	
	init {
		// Test of the connection to the database
		if (!testConnection(MySQL_params)) {
			write "Connection impossible";
			ask (world) {
				do pause;
			}

		} else {
			write "Connection Database OK.";
		}

		list r <- select(MySQL_params,"SELECT stop_times.stop_id, stop_times.arrival_time, stop_times.departure_time
										FROM stop_times
										WHERE stop_times.trip_id = 4503603929213909
											AND stop_times.stop_sequence = 4")[2][0];
		write r;
	}

}

experiment default_expr type: gui {
} 

