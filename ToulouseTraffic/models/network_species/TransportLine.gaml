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
	
	//store all the geometry corresponding to trips made by this line
	map<string,geometry> line_shapes <- [];
	
	//store the correspondance between a trip_id the shape_id it has to follow
	//This map is filled when getStartingTimes is called
	map<string,string> trip_shapes <- [];
	
	rgb line_color <- #black;
	
	//store the trips info
	// key = trip_id matrix = [int arrival_time, int departure_time, Hub hub_to_collect]
	map<string,matrix> trips;
	
	//[int starting_time, string trip_id, int hub_id]
	matrix starting_times <- [];
	int last_starting <- 0;
	
	bool end_of_day <- false;
	
	//reflex function that create transports when it arrives at the first station of the trip
	reflex start_trip when: int(starting_times[0,last_starting]) < current_time and !end_of_day {
		list tempTransportInfo;
		Hub tempHub;
		loop while: int(starting_times[0,last_starting]) < current_time and !end_of_day{
			switch transport_type{
				match 3{
					create Bus{
						id <- myself.starting_times[1,myself.last_starting];
						stop_times <- myself.trips[self.id];
						path_to_use <- as_edge_graph(myself.line_shapes[myself.trip_shapes[self.id]]);
						color <- myself.line_color;
						status <- "waiting";
						day_of_departure <- current_day;
						target <- Hub(stop_times[2,0]);
						tp_line <- myself;
						speed <- 50 #km/#h;
						seq_stop <- 0;
						location <- target.location;
					}
				}
				match 0{
					create Tram{
						id <- myself.starting_times[1,myself.last_starting];
						stop_times <- myself.trips[self.id];
						path_to_use <- as_edge_graph(myself.line_shapes[myself.trip_shapes[self.id]]);
						color <- myself.line_color;
						status <- "waiting";
						day_of_departure <- current_day;
						target <- Hub(stop_times[2,0]);
						tp_line <- myself;
						speed <- 18 #km/#h;
						seq_stop <- 0;
						location <- target.location;
					}
				}
				match 1{
					create Metro{
						id <- myself.starting_times[1,myself.last_starting];
						stop_times <- myself.trips[self.id];
						path_to_use <- as_edge_graph(myself.line_shapes[myself.trip_shapes[self.id]]);
						color <- myself.line_color;
						status <- "waiting";
						day_of_departure <- current_day;
						target <- Hub(stop_times[2,0]);
						tp_line <- myself;
						speed <- 36 #km/#h;
						seq_stop <- 0;
						location <- target.location;
					}
				}
			}
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
		string cond <- "trips.service_id IN (";
		loop id over: services_id{
			cond <- cond + id +",";
		}
		cond <- copy_between(cond, 0,length(cond)-1);
		cond <- cond + ")";
		return cond;
	}
	
	action getStartingTimes{
		list result <- select(MySQL_params,
			"SELECT stop_times.stop_id, stop_times.trip_id, stop_times.arrival_time, trips.shape_id
			FROM stop_times
				INNER JOIN trips ON stop_times.trip_id = trips.trip_id
    			INNER JOIN routes ON trips.route_id = routes.route_id
			WHERE routes.route_id = "+id+"
				AND stop_times.stop_sequence = 0
				AND "+getConditionServices(services_id)+"
			ORDER BY stop_times.arrival_time")[2];
		loop line over: result{
			//get the association between a trip_id and his shape_ip
			trip_shapes[string(line[1])] <- string(line[3]);
			//filling the starting_times matrix
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
    			AND "+getConditionServices(services_id)+"
			ORDER BY shapes.shape_id, shapes.shape_pt_sequence")[2];
		
		string shape_id <-"-1";
		list<point> shape_compo <- [];
		loop line over:result{
			if line[3] = 0 {
				if empty(shape_compo){
					shape_id <- string(line[0]);
					shape_compo <- shape_compo + [string2point(line[2],line[1])];
				}else{
					line_shapes[shape_id] <- polyline(shape_compo);
					shape_id <- string(line[0]);
					shape_compo <- [string2point(line[2],line[1])];
				}
			}else{
				shape_compo <- shape_compo + [string2point(line[2],line[1])];
			}
		}
		line_shapes[shape_id] <- polyline(shape_compo);
	}
	
	action getTripsInfo{
		list result <- select(MySQL_params,
			"SELECT DISTINCT trips.trip_id, stop_times.stop_id, stop_times.arrival_time, stop_times.departure_time, stop_times.stop_sequence
			FROM stop_times
				INNER JOIN trips ON stop_times.trip_id = trips.trip_id
			WHERE route_id = "+id+"
				AND "+getConditionServices(services_id)+"
			ORDER BY trips.trip_id, stop_times.stop_sequence")[2];
		string trip_id <-"-1";
		matrix stop_times <- [];
		Hub tempHub;
		loop line over:result{
			tempHub <- Hub(hubs_map[string(line[1])]);
			if string(line[0]) != trip_id {
				if stop_times.rows = 0 {
					trip_id <- string(line[0]);
					stop_times <- matrix([string2time(line[2]), string2time(line[3]), tempHub]);
				}else{
					trips[trip_id] <- stop_times;
					trip_id <- string(line[0]);
					stop_times <- matrix([string2time(line[2]), string2time(line[3]), tempHub]);
				}
			}else{
				stop_times <- stop_times append_vertically matrix([string2time(line[2]), string2time(line[3]), tempHub]);
			}
		}
		trips[trip_id] <- stop_times;
	}
	
	aspect base { 
		loop tp_line over: line_shapes{
			draw tp_line color: line_color; 
		}	
	}
}

