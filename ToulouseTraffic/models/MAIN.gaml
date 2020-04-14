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
  	
  	string CSV_directory <- "output";
  	string trips_CSV_file <- "trips.csv";
  	string stop_times_CSV_file <- "stop_times.csv";
  	
  	//extracted data count
  	int count_departure <- 0;
  	int count_trip_info <- 0;
  	int count_trip_time <- 0;
  	
  	//number of living agents
  	int nb_metro <- 0 update: length(Metro);
  	int nb_bus <- 0 update: length(Bus);
  	int nb_tram <- 0 update: length(Tram);
  	
	//Shapefile of the buildings
	file building_shapefile <- file("../includes/"+shapefiles_directory+"/"+buildings_shapefile_name);
	//Shapefile of the roads
	file road_shapefile <- file("../includes/"+shapefiles_directory+"/"+roads_shapefile_name);
	//Shape of the environment
	geometry shape <- envelope(road_shapefile);
	//Graph of the road network
	graph road_network;
	
	//Step value
	float step <- 1#mn;
	int current_time update: (time/#mn) mod 1440;
	//this int store an absolute date
	int current_day update: floor(time/#mn /1440);
	//a string to display that correspond to the actual hour
	string disp_hour update: "Day "+current_day+" - "+displayHour(current_time);
	
	
	file trips_file <- csv_file("../includes/" + CSV_directory + "/" + trips_CSV_file);
	file stop_times_file <- csv_file("../includes/" + CSV_directory + "/" + stop_times_CSV_file);
	
	//A list containing all the required parameters to connect to the database
	map<string, string> MySQL_params<- ['host'::'localhost', 'dbtype'::'MySQL', 'database'::'gtfs_toulouse', 'port'::'3306', 'user'::'root', 'passwd'::''];
	
	//A list containing all the service id we want to use to get the data
	list services_id <- ["4503603929111854","4503603929127582"];
	
	string getConditionServices(list services_id){
		string cond <- "AND trips.service_id IN (";
		loop id over: services_id{
			cond <- cond + id +",";
		}
		cond <- copy_between(cond, 0,length(cond)-1);
		cond <- cond + ")";
		return cond;
	}
	
	
	// this function sorts a matrix by a specific column
	// Note that the column type must be able to cast in int
	matrix sortMatrix(matrix data, int column){
		return transpose(matrix(rows_list(data) sort_by int(each[column])));
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
	
	action getHubData {
		list result <- select(MySQL_params,"SELECT DISTINCT stop_id,stop_name,stop_lat,stop_lon FROM stops")[2];
		int count <- 0;
		loop line over: result{
			create Hub{
				id <- string(line[0]);
				name <- line[1];
				location <- myself.string2point(line[3],line[2]);
			}
			count <- count +1;
		}
		write ""+ count + " hubs imported.";
	}	
	
	action getTransportLineData {
		list result <- select(MySQL_params,"SELECT routes.route_id, routes.route_short_name, routes.route_long_name, routes.route_type, routes.route_color FROM routes")[2];
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
					write "no starting times for line "+ long_name +" self-destruct" color: #red;
					do die;
				}else{
					write "line "+ long_name +" ok" color: #green;
					count <- count +1;
				}
				do getShapes;
			}
			
		}
		write ""+ count + " active transport lines imported.";
	}
	
	init {
		// Test of the connection to the database
		do dbTestConnection(MySQL_params);
		
		// Import data and create Hubs
		do getHubData;
		
		// Import data and create transport lines
		do getTransportLineData;
		
		//Initialization of the building using the shapefile of buildings
		//create building from: building_shapefile;
		//Initialization of the road using the shapefile of roads
		create Road from: road_shapefile;
		//creating the road graph
      	road_network <- as_edge_graph(Road);      	
		
	}
		
	//This boolean stop any departure while there is not a new day
	bool end_of_day <- false;
	
	reflex resetEndofDay when: current_time =0{
		end_of_day <- false;
	}
	
}