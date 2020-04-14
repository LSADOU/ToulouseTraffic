/***
* Name: TransportLine
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model TransportLine

import "../MAIN.gaml"
import "Hub.gaml"

species TransportLine skills: [SQLSKILL]{
	
	string id <- "0";
	string short_name <- "default";
	string long_name <- "default";
	
	// 3 = bus / 0 = tram / 1 = metro
	int transport_type <- 3;
	
	list<geometry> line_shapes <- [];
	rgb line_color <- #black;
	
	//[starting_time, trip_id, first hub of the trip]
	matrix starting_times <- [];
	int last_starting <- 0;
	
	//reflex function that create transports when it arrives at the first station of the trip
	reflex start_trip when: int(starting_times[0,last_starting]) < current_time and !end_of_day {
		list tempTransportInfo;
		Hub tempHub;
		loop while: int(starting_times[0,last_starting]) < current_time and !end_of_day{
			tempTransportInfo <- getHubInfo(starting_times[1,last_starting],0);
			switch transport_type{
				match 3{
					create Bus{
						id <- myself.starting_times[1,myself.last_starting];
						status <- "waiting";
						day_of_departure <- current_day;
						tp_line <- myself;
						target <- Hub(tempTransportInfo[0]);
						target_seq_stop <- 0;
						target_arrival_time <- tempTransportInfo[1];
						target_departure_time <- tempTransportInfo[2];
						last_target <- tempTransportInfo[3];
						speed<-50 #km/#h;
						location <-target.location;
					}
				}
				match 0{
					create Tram{
						id <- myself.starting_times[1,myself.last_starting];
						status <- "waiting";
						day_of_departure <- current_day;
						tp_line <- myself;
						target <- tempTransportInfo[0];
						target_seq_stop <- 0;
						target_arrival_time <- tempTransportInfo[1];
						target_departure_time <- tempTransportInfo[2];
						last_target <- tempTransportInfo[3];
						speed<-18 #km/#h;
						location <- target.location;
					}
				}
				match 1{
					create Metro{
						id <- myself.starting_times[1,myself.last_starting];
						status <- "waiting";
						day_of_departure <- current_day;
						tp_line <- myself;
						target <- Hub(tempTransportInfo[0]);
						target_seq_stop <- 0;
						target_arrival_time <- tempTransportInfo[1];
						target_departure_time <- tempTransportInfo[2];
						last_target <- tempTransportInfo[3];
						speed<-36 #km/#h;
						location <- target.location;
					}
				}
			}
			write "création transport sur la ligne " + long_name;
			last_starting <- (last_starting +1) mod starting_times.rows;
			end_of_day <- last_starting = 0;
		}
	}
	
	point string2point(string lon, string lat){
		return point(to_GAMA_CRS({float(lon),float(lat),0}));
	}
	
	float string2time(string time){
		return (int(date(time,"HH:mm:ss"))+3600)/60;
	}
	
	string getConditionServices(list services_id){
		string cond <- "AND trips.service_id IN (";
		loop id over: services_id{
			cond <- cond + id +",";
		}
		cond <- copy_between(cond, 0,length(cond)-1);
		cond <- cond + ")";
		return cond;
	}
	
	action getStartingTimes{
		list result <- select(MySQL_params,
			"SELECT stop_times.stop_id, stop_times.trip_id, stop_times.arrival_time
			FROM stop_times
				INNER JOIN trips ON stop_times.trip_id = trips.trip_id
    			INNER JOIN routes ON trips.route_id = routes.route_id
			WHERE routes.route_id = "+id+"
				AND stop_times.stop_sequence = 0
				"+getConditionServices(services_id)+"
			ORDER BY stop_times.arrival_time")[2];
		loop line over: result{
			if starting_times.rows=0 {
				starting_times <-  matrix([string2time(line[2]),string(line[1]),string(line[0])]);
			}else{
				starting_times <- starting_times append_vertically matrix([string2time(line[2]),string(line[1]),string(line[0])]);
			}
		}
	}
	
	action getShapes{
		list result <- select(MySQL_params,
			"SELECT DISTINCT shapes.shape_id, shapes.shape_pt_lat, shapes.shape_pt_lon, shapes.shape_pt_sequence
			FROM trips
				INNER JOIN shapes ON trips.shape_id = shapes.shape_id
    			INNER JOIN routes ON trips.route_id = routes.route_id
			WHERE routes.route_id = "+id+"
    			"+getConditionServices(services_id)+"
			ORDER BY shapes.shape_id, shapes.shape_pt_sequence")[2];
		
		int shape_id <-0;
		list<point> shape_compo <- [];
		loop line over:result{
			if line[3] = 0 {
				if empty(shape_compo){
					shape_id <- line[0];
					shape_compo <- shape_compo + [string2point(line[2],line[1])];
				}else{
					line_shapes <- line_shapes + [polyline(shape_compo)];
					shape_id <- line[0];
					shape_compo <- [];
				}
			}else{
				shape_compo <- shape_compo + [string2point(line[2],line[1])];
			}
		}
		line_shapes <- line_shapes + [polyline(shape_compo)];
	}
	
	//return a list containing info about a specific hub
	//this action has to be called by transport using this tp line
	//returned list = [Hub target, int arrival_time, int departure_time, bool last_target]
	list getHubInfo(string transport_id, int seq_stop){
		list result <- select(MySQL_params,
			"SELECT stop_times.stop_id, stop_times.arrival_time, stop_times.departure_time
			FROM stop_times
			WHERE stop_times.trip_id = "+transport_id+"
				AND stop_times.stop_sequence = "+seq_stop)[2];
		if length(result) = 0{
			write "SELECT stop_times.stop_id, stop_times.arrival_time, stop_times.departure_time
			FROM stop_times
			WHERE stop_times.trip_id = "+transport_id+"
				AND stop_times.stop_sequence = "+seq_stop;
		}
		result <- result[0];
		Hub h <- Hub first_with (each.id contains string(result[0]));
		int max_seq_stop <- select(MySQL_params,
			"SELECT  MAX(stop_times.stop_sequence)
			FROM stop_times
			WHERE stop_times.trip_id = "+transport_id)[2][0][0];
		return [h, string2time(result[1]), string2time(result[2]),max_seq_stop=seq_stop];
	}
	
	aspect base { 
		loop tp_line over: line_shapes{
			draw tp_line color: line_color; 
		}	
	}
}

