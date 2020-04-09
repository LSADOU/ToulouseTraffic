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

global {
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
	float step <- 10;
	int current_time update: (time/#mn) mod 1440;
	//this int store an absolute date
	int current_day update: floor(time/#mn /1440);
	//a string to display that correspond to the actual hour
	string disp_hour update: "Day "+current_day+" - "+displayHour(current_time);
	
	//those two maps have a trip_id as key
	//the first map contains a matrix wich describe the trip using stop time and location
	map<string,matrix> trip_time_map;
	//the second one contains basic information about the trip itself
	map<string,list> trip_info_map;
	//This matrix contains only two columns, the first column is filled with time information and
	//the second column is a trip_id. The purpose of this matrix is to create a common transport
	//when it arrives at the first sation. This matrix comes with a pointer to indicate the last
	//hour computed for not having to parse the whole matrix each time. Obviously, this matrix has
	//to be sorted by chronological order.
	matrix starting_times <- [];
	int last_starting <- 0;
	
	file trips_file <- csv_file("../includes/" + CSV_directory + "/" + trips_CSV_file);
	file stop_times_file <- csv_file("../includes/" + CSV_directory + "/" + stop_times_CSV_file);
	
	// this function implement the bubble sort to sort matrix by a specific column
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
	
	init {
		//**********************Filling the maps****************
		matrix data <- matrix(trips_file);
		string temp_type;
		loop i from: 0 to: data.rows -1{
			count_trip_info <- count_trip_info+1;
			switch data[3,i]{
				match "0"{temp_type <- "tram";}
				match "1"{temp_type <- "metro";}
				default{temp_type <- "bus";}	
			}
			trip_info_map[data[0,i]] <- [data[1,i],data[2,i],temp_type];
		}
		
		data <- matrix(stop_times_file);
		point tempPoint;
		loop i from: 0 to: data.rows -1{
			tempPoint <- point({float(data[5,i]),float(data[4,i]),0});
			tempPoint <- to_GAMA_CRS(tempPoint);
			if trip_time_map.keys contains data[2,i] {
				trip_time_map[data[2,i]] <- 
					trip_time_map[data[2,i]] 
					append_vertically 
					//the hours are stored in minutes because i found it was easier to manipulate
					//the longitude and latitude are stored as a point geometry
					matrix([data[1,i],
							data[3,i],
							tempPoint,
							int(data[6,i]),
							(int(date(string(data[7,i]),"HH:mm:ss"))+3600)/60,
							(int(date(string(data[8,i]),"HH:mm:ss"))+3600)/60]);
			}else{
				count_trip_time <- count_trip_time+1;
				trip_time_map[data[2,i]] <-matrix([data[1,i],
												   data[3,i],
												   tempPoint,
												   int(data[6,i]),
												   (int(date(string(data[7,i]),"HH:mm:ss"))+3600)/60,
												   (int(date(string(data[8,i]),"HH:mm:ss"))+3600)/60]);
			}
			if data[6,i] = "0" {
				count_departure <- count_departure +1;
				if starting_times.rows=0 {
					starting_times <-  matrix([(int(date(string(data[7,i]),"HH:mm:ss"))+3600)/60,
											   data[2,i],
											   tempPoint]);
				}else{
					starting_times <- starting_times 
									  append_vertically 
									  matrix([(int(date(string(data[7,i]),"HH:mm:ss"))+3600)/60,
									  		  data[2,i],
									  		  tempPoint]);
				}
			}
		}
		write ""+ count_trip_info + " trip informations extracted";
		write ""+ count_trip_time + " trip times extracted";
		write ""+ count_departure + " departures extracted";
		//**********************************************************
		//*********Sorting departures matrix and trip matrix********
		write "sorting trip matrix...";
		loop k over: trip_time_map.keys{
			trip_time_map[k] <- sortMatrix(trip_time_map[k],4);
			//write k;
			//write trip_time_map[k];
			
		}
		write "sorting departures matrix...";
		starting_times <- sortMatrix(starting_times,0);
		
		//**********************************************************
		//***************Creating agents****************************
		//Initialization of the building using the shapefile of buildings
		//create building from: building_shapefile;
		//Initialization of the road using the shapefile of roads
		create Road from: road_shapefile;
		//creating the road graph
      	road_network <- as_edge_graph(Road);      	
      	//**********************************************************
	}
		
	//This boolean stop any departure while there is not a new day
	bool end_of_day <- false;
	
	reflex resetEndofDay when: current_time =0{
		end_of_day <- false;
	}
	
	//reflex function that create transports when it arrives at the first station of the trip
	reflex start_trip when: int(starting_times[0,last_starting]) < current_time and !end_of_day {
		list tempTransportInfo;
		loop while: int(starting_times[0,last_starting]) < current_time and !end_of_day{
			tempTransportInfo <- trip_info_map[starting_times[1,last_starting]];
			switch tempTransportInfo[2]{
				match "bus"{
					create Bus{
						id <- starting_times[1,last_starting];
						tempTransportInfo <- trip_info_map[id];
						trip_stop_times <- trip_time_map[id];
						target_seq_stop <- 0;
						status <- "waiting";
						speed<-50 #km/#h;
						day_of_departure <- current_day;
						location <- starting_times[2,last_starting];
					}
				}
				match "tram"{
					create Tram{
						id <- starting_times[1,last_starting];
						tempTransportInfo <- trip_info_map[id];
						trip_stop_times <- trip_time_map[id];
						target_seq_stop <- 0;
						status <- "waiting";
						speed<-18 #km/#h;
						day_of_departure <- current_day;
						location <- starting_times[2,last_starting];
					}
				}
				match "metro"{
					create Metro{
						id <- starting_times[1,last_starting];
						tempTransportInfo <- trip_info_map[id];
						trip_stop_times <- trip_time_map[id];
						target_seq_stop <- 0;
						status <- "waiting";
						speed<-36 #km/#h;
						day_of_departure <- current_day;
						location <- starting_times[2,last_starting];
					}
				}
			}
			write "création du "+ tempTransportInfo[2]+ " " + tempTransportInfo[1] +" à "+ displayHour(current_time);
			last_starting <- (last_starting +1) mod starting_times.rows;
			end_of_day <- last_starting = 0;
		}
	}
}


experiment traffic type: gui {
	float minimum_cycle_duration <- 0.01;
	output {
		//layout #split parameters: false navigator: false editors: false consoles: false toolbars: false tray: false tabs: false;	
		display map type: opengl{
			graphics "hour of the day"{
				draw disp_hour at: {0,-120} size: 100 color: #black;
			}
			species Building refresh: false;
			species Road refresh: false;
			species Bus aspect: base;
			species Tram aspect: arrowAspect;
			species Metro aspect: arrowAspect;
		}
		display charts refresh: every (10 #cycles){
			chart "Mean late time" type: series size: {1, 0.5} position: {0, 0} {
        		data "Mean metros late time" value: mean(Metro collect each.mean_late_time) style: line color: #red;
        		data "Mean bus late time" value: mean(Bus collect each.mean_late_time) style: line color: #blue;
      		}
      		chart "Number of working transports" type: series size: {1, 0.5} position: {0, 0.5} {
        		data "Number of working metros" value: nb_metro  style: line color: #red;
        		data "Number of working bus" value: nb_bus  style: line color: #blue;
        	} 
		}
	}
}