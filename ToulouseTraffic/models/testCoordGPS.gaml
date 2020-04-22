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
	
	int date2day(string date_){
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
			return int(((day_code mod 7) + (year_code mod 7) + month_code) mod 7);
	}
	
	init {
      	road_network <- as_edge_graph(road);
      	
      	point testGPS <- point({float("1.448519"),float("43.605606"),0});
      	write testGPS;
      	point testGPS2GAMA <- point(to_GAMA_CRS({float("1.448519"),float("43.605606"),0}));
      	write testGPS2GAMA;
      	int minuit <- (int(date("00:00:00","HH:mm:ss"))+3600)/60;
      	int heure1 <- (int(date("01:00:00","HH:mm:ss"))+3600)/60;
      	int heure12 <- (int(date("12:00:00","HH:mm:ss"))+3600)/60;
      	
      	int nb_heure <- int(heure1/60);
      	int nb_min <- heure1 mod 60;
      	
      	string date_test <- "20200416";
      	write date2day(date_test);
      	
      	write "clean road";
      	//clean data, with the given options
		//list<geometry> clean_lines <- clean_network(road_shapefile.contents,1000.0,false,true);
		//create road from the clean lines
		create road from: road_shapefile;
		//save road to: "../includes/full_shapefiles/cleanroads.shp" type: shp;
      	
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
