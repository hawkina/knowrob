/** <module> comp_orgprinciples

  This module contains all computables that compute the location where 
  an object should be placed given other objects at different locations
  in the environment. Can also be used to infer where an object could
  probably be found, given earlier (outdated) observations of other
  objects in the environment. Uses the WUP similartiy from
  comp_similartiy module.


  Copyright (C) 2011 Martin Schuster

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

@author Martin Schuster
@license GPL
*/

:- module(comp_orgprinciples,
    [
		best_location_maxMaxWup/2,
		best_location_dtree/2
    ]).

:- use_module(library('semweb/rdf_db')).
:-  rdf_meta
	  best_location_maxMaxWup(r,-),
	  best_location_dtree(r,-),
	  objects_at_location(r,-),
	  class_of_object(r,r),
	  classes_of_objects(t,t).

%% best_location_maxMaxWup(+Object, -BestLocation).	  
%
% computes the best location where to place a certain object
% may give multiple possible solutions in case there is a tie
%
% Example: best_location_maxMaxWup(orgprinciples_demo:'Muesli_Schoko_1', L).
% Example: best_location_maxMaxWup(knowrob:'Knife', L).
%
% @param Object Object or Class
% @param BestLocation accoring to max. maxWup similarity
best_location_maxMaxWup(Object, BestLocation)	:-
    (class_of_object(Class1, Object) -> Class = Class1 ; Class = Object),
    all_locations(Locations),
    findall(MaxSim, (
    	member(Location, Locations),
    	objects_at_location(Location, ObjectsAtLocation),
    	classes_of_objects(ClassesAtLocation, ObjectsAtLocation),
    	max_similarity_object_location(comp_similarity:rdf_wup_similarity, Class, ClassesAtLocation, MaxSim),  
    	format('maxWup ~w at location ~w',[MaxSim, Location]), nl %debug output
    ), MaxSimList),
    max_list(MaxSimList, MaxMaxSim),
    nth0(Index, MaxSimList, MaxMaxSim),
    nth0(Index, Locations, BestLocation).
 
 
%% best_location_dtree(+Object, -BestLocation)    
%
% computes the best location where to place a certain object
%
% Example: best_location_dtree(orgprinciples_demo:'Muesli_Schoko_1', L).
% Example: best_location_dtree(knowrob:'Knife', L).
%
% @param Object Object or Class
% @param BestLocation accoring to Decision Trees, features are maxWup and avgWup similaritites
% uses the WEKA C4.5 Decision Tree (J48) classifier (unpruned, min. number of instances per leaf = 0)
best_location_dtree(Object, BestLocation) :-
    (class_of_object(Class1, Object) -> Class = Class1 ; Class = Object),
    all_locations(Locations),
    objects_at_location(_, AllObjects),
    %prepare training data:
    %compute similarties of every object with every location 
    findall(Trainingsdatum, (
    	member(TrainingsObject, AllObjects),
    	class_of_object(TrainingsClass, TrainingsObject),
    	findall(Similarities, (
    		member(Location, Locations),
    		objects_at_location(Location, ObjectsAtLocation),
    		% the following exclusion does not perform well in case there is only one object at a location
	    		%exclude classes of TrainingObject from location:
	    		subtract(ObjectsAtLocation, [TrainingsObject], ObjectsAtLocationWithoutT), 
	    		classes_of_objects(ClassesAtLocation, ObjectsAtLocationWithoutT),
    		%classes_of_objects(ClassesAtLocation, ObjectsAtLocation),
    		max_similarity_object_location(comp_similarity:rdf_wup_similarity, TrainingsClass, ClassesAtLocation, MaxSim),
    		avg_similarity_object_location(comp_similarity:rdf_wup_similarity, TrainingsClass, ClassesAtLocation, AvgSim),
    		%format('maxWup ~w, avgWup ~w at location ~w',[MaxSim, AvgSim, Location]), nl, %debug output
    		Similarities = [MaxSim, AvgSim]  
    	),SimilaritiesAllLocations),
    	owl_has(TrainingsObject, knowrob:'in-ContGeneric', TrainingsObjectLocation),
    	flatten(SimilaritiesAllLocations, SimilaritiesAllLocationsFlat),
    	Trainingsdatum = [TrainingsObjectLocation | SimilaritiesAllLocationsFlat]
    ), Trainingsdata),
    %write(Trainingsdata),nl, %debug output
    %train classifier: (options: -U: unpruned, -M 0: min. number of instances per leaf = 0)
    classifier_trained(Classifier, 'weka.classifiers.trees.J48', '-U -M 0', Trainingsdata),
    
    %prepare test data: 
    %compute similarities of test object with every location
	findall(TestSimilarities, (
		member(TestLocation, Locations),
		objects_at_location(TestLocation, ObjectsAtTestLocation),
		classes_of_objects(ClassesAtTestLocation, ObjectsAtTestLocation),
		max_similarity_object_location(comp_similarity:rdf_wup_similarity, Class, ClassesAtTestLocation, TestMaxSim),
		avg_similarity_object_location(comp_similarity:rdf_wup_similarity, Class, ClassesAtTestLocation, TestAvgSim),
		format('Test: maxWup ~w, avgWup ~w at location ~w',[TestMaxSim, TestAvgSim, TestLocation]), nl, %debug output
		TestSimilarities = [TestMaxSim, TestAvgSim]  
	),TestSimilaritiesAllLocations),
	flatten(TestSimilaritiesAllLocations, TestSimilaritiesAllLocationsFlat),
	%write(TestSimilaritiesAllLocationsFlat),nl, %debug output
    %classify Object:
    classify_instances(Classifier, [TestSimilaritiesAllLocationsFlat] ,BestLocationList),
    nth0(0, BestLocationList, BestLocation).
    
	
%% classes_of_objects(-Classes, +Objects)
%
% get all classes, one for each object for a list of objects
% in case of multiple classes per object, return first (random?)
% only returns classes that are subclasses of knowrob:'SpatialThing'
%
% @param Classes List of classes
% @param Objects List of instances
classes_of_objects(Classes, Objects) :-
    findall(Class, (
	    member(Object, Objects),
	    class_of_object(Class, Object)
    ), Classes).
    
    
%% class_of_object(-Class, +Object)
%
% get all class for object (instance)
% in case of multiple classes, return first (random?)
% only returns classes that are subclasses of knowrob:'SpatialThing'
class_of_object(Class, Object) :-
	owl_has(Object, rdf:type, Class), 
	owl_subclass_of(Class, 'http://ias.cs.tum.edu/kb/knowrob.owl#SpatialThing'), %only consider relevant object classes
	! %if there are multiple, just take the first one for now
	.

%% all_locations(-Locations)
%
% get all locations defined in the environment through in-ContGeneric relations
all_locations(Locations) :-
    findall(L, owl_has(_, knowrob:'in-ContGeneric', L), Ls),
	list_to_set(Ls, Locations).  
	
	
%% objects_at_location(+Location, -Objects)
%
% get all objects at a location
objects_at_location(Location, Objects) :-
    findall(O, owl_has(O, knowrob:'in-ContGeneric', Location), Objects). 
	  
	  
%% avg_similarity_object_location(:SimFct:predicate, +Class:rdf_class, +List:list, -Average:float).
%
% uses SimFct to compute the similarity between a class and a list of classes (=location)
% averages the similarities of all classes in the list
%
% @param SimFct similarity function SimFct(+Class1, +Class2, -Similartiy)
% @param Class class to compute similiarities with location
% @param List list of classes that define the location
% @param Average similarity of Class with List
avg_similarity_object_location(SimFct, Class, List, Average) :-
    (List = [] -> Average is 0 ; (
	similarities(SimFct, Class, List, Similarities),
	average(Similarities, Average))).
	
%% max_similarity_object_location(:SimFct:predicate, +Class:rdf_class, +List:list, -Average:float).
%
% uses SimFct to compute the similarity between a class and a list of classes (=location)
% takes the maximum similartiy of all classes in the list
%
% @param SimFct similarity function SimFct(+Class1, +Class2, -Similartiy)
% @param Class class to compute similiarities with location
% @param List list of classes that define the location
% @param Average similarity of Class with List
max_similarity_object_location(SimFct, Class, List, Max) :-
    (List = [] -> Max is 0 ; (
	similarities(SimFct, Class, List, Similarities),
	max_list(Similarities, Max))).
	
	
%% similarities(:SimFct:predicate, +Class:rdf_class, +[H|T]:list, -Similarities:list).
%
% compute similarity of an object to each element of a list of object, using SimFct/3 
%
% @param SimFct similarity function SimFct(+Class1, +Class2, -Similartiy)
% @param Class class to compute similiarities with location
% @param [H|T] list of classes that define the location
% @param Similarities similarities of Class with each element of [H|T]   
similarities(_, _,[], []).
similarities(SimFct, Class, [H|T], Similarities) :-
    %to_global(H, HGlobal),
    %to_global(Class, ClassGlobal),
    %call(SimFct, ClassGlobal, HGlobal, Similarity),
    call(SimFct, Class, H, Similarity),
    similarities(SimFct, Class, T, SimilaritiesTail),
    append([Similarity] , SimilaritiesTail, Similarities).
	  
	  
	  
	  
% utility functions:
average(List, Average) :-
	count_sum(List, Count, Sum),
	Average is Sum / Count.    
    
count_sum([], 0, 0).
count_sum([H|T], Count, Sum) :-
	count_sum(T, C1, S1),
	Count is C1 + 1,
	Sum is S1 + H.
	  