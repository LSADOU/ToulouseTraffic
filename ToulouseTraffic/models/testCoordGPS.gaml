/**
* Name: Traffic
* Author: Patrick Taillandier
* Description: A simple traffic model with a pollution model: the speed on a road depends on the number of people 
* on the road (the highest, the slowest), and the people diffuse pollution on the envrionment when moving.
* Tags: gis, shapefile, graph, skill, transport
*/

model testCoordGPS

global {
	string shapefiles_directory <- "full_shapefiles";
  	string buildings_shapefile_name <- "buildings";
  	string roads_shapefile_name <- "roads";
	//Shapefile of the buildings
	file building_shapefile <- file("../includes/full_shapefiles/buildings.shp");
	//Shapefile of the roads
	file road_shapefile <- file("../includes/full_shapefiles/roads.shp");
	//Shape of the environment
	geometry shape <- envelope(road_shapefile);
	//Step value
	float step <- 10 #s;
	//Graph of the road network
	graph road_network;
	//Map containing all the weights for the road network graph
	map<road,float> road_weights;
	
	init {
      	road_network <- as_edge_graph(road);
      	
      	point testGPS <- point({float("1.448519"),float("43.605606"),0});
      	write testGPS;
      	point testGPS2GAMA <- to_GAMA_CRS(testGPS);
      	write testGPS2GAMA;
      	int minuit <- (int(date("00:00:00","HH:mm:ss"))+3600)/60;
      	int heure1 <- (int(date("01:00:00","HH:mm:ss"))+3600)/60;
      	int heure12 <- (int(date("12:00:00","HH:mm:ss"))+3600)/60;
      	
      	int nb_heure <- int(heure1/60);
      	int nb_min <- heure1 mod 60;
      	
      	string s <- "";
      	
      	if nb_heure < 10 {
      		s <- s +"0";
      	}
      	s <- s + nb_heure + "h";
      	
      	if nb_min < 10 {
      		s <- s +"0";
      	}
      	s <- s + nb_min;
      	
      	
      	write s;
      	write minuit;
      	write heure1;
      	write heure12;	
      	
      	write "clean road";
      	//clean data, with the given options
		list<geometry> clean_lines <- clean_network(road_shapefile.contents,1000.0,false,true);
		//create road from the clean lines
		create road from: clean_lines;
		save road to: "../includes/full_shapefiles/cleanroads.shp" type: shp;
      	
      	create test{
      		location <- testGPS2GAMA;
      	}
	}
}

//Species to represent the buildings
species building {
	aspect default {
		draw shape color: #gray;
	}
}
//Species to represent the roads
species road {
	aspect default {
		draw shape color: #black;
	} 
}

species test{
	aspect default{
		draw circle(100) color: #red;
	}
}

experiment traffic type: gui {
	float minimum_cycle_duration <- 0.01;
	output {
		display carte type: opengl{
			species building refresh: false;
			species road ;
			species test;
		}
	}
}
