/***
* Name: NewModel
* Author: Lo�c
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model MAIN

import "transports_species/Transport.gaml"
import "transports_species/Bus.gaml"
import "transports_species/Metro.gaml"
import "transports_species/Tram.gaml"

import "urban_species/Road.gaml"
import "urban_species/Building.gaml"

import "experiments/main_exp.experiment"

global skills: [SQLSKILL]{
	string shapefiles_directory <- "full_shapefiles";
  	string buildings_shapefile_name <- "buildings.shp";
  	string roads_shapefile_name <- "cleanroads.shp";
  	
  	
  	//extracted data count
  	int count_departure <- 0;
  	int count_trip_info <- 0;
  	int count_trip_time <- 0;
  	
  	//number of living agents
  	int nb_metro <- 0 update: length(Metro);
  	int nb_bus <- 0 update: length(Bus);
  	int nb_tram <- 0 update: length(Tram);
  	
  	string disp_species_number update:
  	 "Metro number: "+ nb_metro + "\n"+
  	 "Bus number: "+ nb_bus + "\n"+
  	 "Tram number: "+ nb_tram;
  	
	//Shapefile of the buildings
	file building_shapefile <- file("../includes/"+shapefiles_directory+"/"+buildings_shapefile_name);
	//Shapefile of the roads
	file road_shapefile <- file("../includes/"+shapefiles_directory+"/"+roads_shapefile_name);
	//Shape of the environment
	geometry shape <- envelope(road_shapefile);
	//Graph of the road network
	graph road_network;
	
	//Step value
	float step <- 30#sec;
	int current_time update: (time/#mn) mod 1440;
	//this int store an absolute date
	int current_day update: floor(time/#mn /1440);
	//a string to display that correspond to the actual hour
	string disp_hour update: "Day "+current_day+" - "+displayHour(current_time);
	
	//A list containing all the required parameters to connect to the database
	map<string, string> MySQL_params<- ['host'::'localhost', 'dbtype'::'MySQL', 'database'::'gtfs_toulouse', 'port'::'3306', 'user'::'root', 'passwd'::''];
	
	//A list containing all the service id we want to use to get the data from
	//list<string> services_id <- ["4503603929111854","4503603929127582"];
	list<string> services_id <- [];
	
	//The date to simulate, used to compute wich services are on
	string simulation_date <- "20200416";
	
	string date2day(string date_){
		int day_code <- int(copy_between(date_,6,8));
			int year_num <- int(copy_between(date_,2,4));
			int year_code <- year_num + floor(year_num /4);
			int month_code;
			switch copy_between(date_,4,6){
				match "01"{ if (year_num mod 4)=0 {month_code <- 5;}else{ month_code <- 6;} }
				match "02"{ if (year_num mod 4)=0 {month_code <- 1;}else{ month_code <- 2;} }
				match "03"{month_code <- 2;}
				match "04"{month_code <- 5;}
				match "05"{month_code <- 0;}
				match "06"{month_code <- 3;}
				match "07"{month_code <- 5;}
				match "08"{month_code <- 1;}
				match "09"{month_code <- 4;}
				match "010"{month_code <- 6;}
				match "11"{month_code <- 2;}
				match "12"{month_code <- 4;}
			}
			int day_num <- int(((day_code mod 7) + (year_code mod 7) + month_code) mod 7);
			switch day_num{
				match 1 {return "monday";}
				match 2 {return "tuesday";}
				match 3 {return "wednesday";}
				match 4 {return "thursday";}
				match 5 {return "friday";}
				match 6 {return "saturday";}
				match 7 {return "sunday";}
			}
	}
	
	//this function is used to get the service ids from the database corresponding to the
	//given date, the date as to be formated like gtfs date format: yyyymmjj
	action getServiceIdFromDate{
		if length(simulation_date) != 8{
			write "Cannot get the service id due to invalid date format" color: #red;
		}else{
			string day_num <- date2day(simulation_date);
			list result <- select(MySQL_params,
			"SELECT calendar.service_id
			FROM calendar
			WHERE end_date >= \""+ simulation_date +"\"
				AND start_date <= \""+ simulation_date +"\"
    			AND "+ date2day(simulation_date) +" = 1")[2];
    		loop line over: result{
    			write line[0];
    			services_id <- services_id + [line[0]];
    		}
		}
	}
	
	
	
	string getConditionServices(list<string> servicesId){
		string cond <- "trips.service_id IN (";
		loop id over: servicesId{
			cond <- cond + id +",";
		}
		cond <- copy_between(cond, 0,length(cond)-1);
		cond <- cond + ")";
		return cond;
	}
	
	// this function return a string corresponding to the hour
	string displayHour(int hour){
		int nb_heure <- int(hour/60);
      	int nb_min <- hour mod 60;
      	string s <- "";
      	if nb_heure < 10 {s <- s +"0";}
      	s <- s + nb_heure + "h";
      	if nb_min < 10 {s <- s +"0";}
      	return s + nb_min;
	}
	
	action dbTestConnection(map<string,string> sql_param){
		write "This model will work only if the corresponding database is installed and the database management server launched.";
		loop while: !testConnection(MySQL_params){
			write "Connection impossible" color: #red;
			ask (world) {do pause;}
		}
		write "Connection ok!" color: #green;
	}
	
	point string2point(string lon, string lat){
		return point(to_GAMA_CRS({float(lon),float(lat),0}));
	}
	
	int hex2int(string hex){
		switch hex{
			match "a"{return 10;}
			match "b"{return 11;}
			match "c"{return 12;}
			match "d"{return 13;}
			match "e"{return 14;}
			match "f"{return 15;}
			default{return int(hex);}
		}
	}
	
	rgb hex2rgb(string hex){
		if length(hex) != 6{return #black;}
		hex <- lower_case(hex);
		int r <- hex2int(at(hex,0))*16 + hex2int(at(hex,1));
		int g <- hex2int(at(hex,2))*16 + hex2int(at(hex,3));
		int b <- hex2int(at(hex,4))*16 + hex2int(at(hex,5));
		return rgb(r,g,b);
	}

	//the purpose of this map is to store Hub using their id as key
	//this is useful to get them later and drastically reduce the compute times
	//when lines will associate hubs to trips
	map<string,Hub> hubs_map <- [];
	
	action getHubData {
		list<string> createdRoutesID <- TransportLine collect (each.id);
		list result <- select(MySQL_params,
			"SELECT DISTINCT stops.stop_id,stop_name,stop_lat,stop_lon,routes.route_type
			FROM stops
				INNER JOIN stop_times ON stop_times.stop_id = stops.stop_id
    			INNER JOIN trips ON stop_times.trip_id = trips.trip_id
   				INNER JOIN routes ON trips.route_id = routes.route_id
			WHERE "+getConditionServices(services_id))[2];
		int count <- 0;
		loop line over: result{
			create Hub{
				id <- string(line[0]);
				name <- line[1];
				transport_type <- line[4];
				location <- myself.string2point(line[3],line[2]);
				myself.hubs_map[id] <- self;
			}
			count <- count +1;
		}
		write ""+ count + " hubs imported.";
	}	
	
	action getTransportLineData {
		list result <- select(MySQL_params,
			"SELECT DISTINCT routes.route_id, routes.route_short_name, routes.route_long_name, routes.route_type, routes.route_color 
			FROM routes
				INNER JOIN trips ON routes.route_id = trips.route_id
			WHERE "+getConditionServices(services_id))[2];
		int count <- 0;
		loop line over: result{
			create TransportLine{
				id <- string(line[0]);
				short_name <- line[1];
				long_name <- line[2];
				transport_type <- int(line[3]);
				line_color <- myself.hex2rgb(line[4]);
				do getStartingTimes;
				if starting_times.rows=0{
					do die;
				}else{
					count <- count +1;
				}
				do getShapes;
				do getTripsInfo;
			}
		}
		write ""+ count + " active transport lines imported. (considered the service setup)";
	}
	
	init {
		// Test of the connection to the database
		do dbTestConnection(MySQL_params);
		
		// Import the service ids concerned by the date of the simulation
		do getServiceIdFromDate;
		
		// Import data and create Hubs
		do getHubData;
		
		// Import data and create transport lines
		// Note that creating line after hubs is important beacause each line need hub to be instancied
		// to store the reference
		do getTransportLineData;

		
		//Initialization of the building using the shapefile of buildings
		//create building from: building_shapefile;
		//Initialization of the road using the shapefile of roads
		create Road from: road_shapefile;
		//creating the road graph
      	road_network <- as_edge_graph(Road);      	
		
	}
	
	reflex resetEndofDay when: current_time =0{
		ask TransportLine{
			end_of_day <- false;
		}
	}
	
}