%%
%% Copyright (C) 2016 by Daniel Beßler
%%
%% This file contains tests for the knowrob_temporal module
%%
%% This program is free software; you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation; either version 3 of the License, or
%% (at your option) any later version.
%%
%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.
%%
%% You should have received a copy of the GNU General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%%

:- begin_tests(knowrob_temporal).

:- use_module(library('semweb/rdf_db')).
:- use_module(library('semweb/rdfs')).
:- use_module(library('owl')).
:- use_module(library('owl_parser')).
:- use_module(library('knowrob_owl')).
:- use_module(library('knowrob_temporal')).

:- owl_parser:owl_parse('package://knowrob_common/owl/knowrob_temporal.owl').
:- owl_parser:owl_parse('package://knowrob_common/owl/knowrob_temporal_test.owl').

:- rdf_db:rdf_register_prefix(knowrob_temporal_test, 'http://knowrob.org/kb/knowrob_temporal_test.owl#', [keep(true)]).

:- rdf_meta fluent_begin(r,r,t,r),
            fluent_test_assert(r,r,t).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Interval algebra

test(interval_during0) :-
  interval_during(1.0, [0.0]).

test(interval_during1) :-
  interval_during(1.0, [0.0,2.0]).

test(interval_during2) :-
  interval_during([1.0,2.0], [0.0,2.0]).

test(interval_during3) :-
  interval_during([1.0], [0.0]).

test(interval_during4, [fail]) :-
  interval_during(1.0, [2.0]).

test(interval_during5, [fail]) :-
  interval_during([1.0], [2.0]).

test(interval_during6, [fail]) :-
  interval_during([1.0,3.0], [2.0]).

test(interval_during7, [fail]) :-
  interval_during(6.0, [2.0,4.0]).

test(interval_during8, [fail]) :-
  interval_during([1.0], [2.0,4.0]).

test(interval_during9, [fail]) :-
  interval_during([3.0], [2.0,4.0]).

test(interval_during10, [fail]) :-
  interval_during([2.0,5.0], [2.0,4.0]).

%interval_operator(before, I1, I2) :-   interval_before(I1,I2).
%interval_operator(after, I1, I2) :-    interval_after(I1,I2).
%interval_operator(meets, I1, I2) :-    interval_meets(I1,I2).
%interval_operator(starts, I1, I2) :-   interval_starts(I1,I2).
%interval_operator(finishes, I1, I2) :- interval_finishes(I1,I2).
%interval_operator(overlaps, I1, I2) :- interval_overlaps(I1,I2).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Fluents

fluent_begin(S,P,O,Time) :-
  fluent_assert(S, P, O, Time),
  owl_has(S, knowrob:hasTemporalPart, TemporalPart0),
  (  rdf_has(P, rdf:type, owl:'ObjectProperty')
  -> (
      owl_has(O, knowrob:hasTemporalPart, TemporalPart1),
      rdf_has(TemporalPart0, P, TemporalPart1)
  ) ; (
      rdf_has(TemporalPart0, P, O)
  )),
  interval(TemporalPart0, [Time]).

fluent_test_assert(S,P,[O1,O2]) :-
  fluent_begin(S, P, O1, 0.0),
  %% Assert [?P, 10.0, during, [an, interval, [0.0]]]
  fluent_has(S, P, O1),
  holds(S, P, O1, 20.0),
  holds(S, P, O1, [0.0,60.0]),
  %% Assert [?P, 0.0, during, [an, interval, [0.0,20.0]]],
  fluent_assert_end(S, P, 20.0),
  fluent_has(S, P, O1),
  holds(S, P, O1, 20.0),
  holds(S, P, O1, [0.0,20.0]),
  not( holds(S, P, O1, [0.0,60.0]) ),
  %% Assert [?P, 15.0, during, [an, interval, [20.0]]]
  fluent_begin(S, P, O2, 20.0),
  fluent_has(S, P, O2), !.

test(fluent_assert_data) :-
  Value1_=literal(type(xsd:'float',10.0)), rdf_global_term(Value1_, Value1),
  Value2_=literal(type(xsd:'float',15.0)), rdf_global_term(Value2_, Value2),
  rdf_assert(knowrob_temporal_test:'Dough_vs5hgsg0', rdf:type, knowrob:'Dough'),
  fluent_test_assert(knowrob_temporal_test:'Dough_vs5hgsg0', knowrob:temperatureOfObject, [Value1,Value2]).

test(fluent_assert_object) :-
  Value1_=knowrob_temporal_test:'Container_vs5hgsg0', rdf_global_term(Value1_, Value1),
  Value2_=knowrob_temporal_test:'Container_SFmvd9df', rdf_global_term(Value2_, Value2),
  rdf_assert(knowrob_temporal_test:'Dough_vs5hgsg0', rdf:type, knowrob:'Dough'),
  rdf_assert(Value1, rdf:type, knowrob:'Container'),
  rdf_assert(Value2, rdf:type, knowrob:'Container'),
  fluent_test_assert(knowrob_temporal_test:'Dough_vs5hgsg0', knowrob:insideOf, [Value1,Value2]).


test(fluent_has, [nondet]) :-
  fluent_has(knowrob_temporal_test:'Dough_vs5hgsg0', knowrob:temperatureOfObject,
             literal(type(xsd:'float',10.0)), I),
  interval(I, [0.0,20.0]).

test(fluent_has_O_unbound, [nondet]) :-
  fluent_has(knowrob_temporal_test:'Dough_vs5hgsg0', knowrob:temperatureOfObject, O, I),
  interval(I, [0.0,20.0]),
  O = literal(type(_,10.0)).

test(fluent_has_S_P_O_unbound, [nondet]) :-
  fluent_has(S, P, O, I),
  S = 'http://knowrob.org/kb/knowrob_temporal_test.owl#Dough_vs5hgsg0',
  P = 'http://knowrob.org/kb/knowrob.owl#temperatureOfObject',
  interval(I, [0.0,20.0]),
  O = literal(type(_,10.0)).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% `holds`

test(holds) :- fail. % TODO: write test with object property

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% `òccurs`

test(occurs) :- fail. % TODO: write test with object property

:- end_tests(knowrob_temporal).