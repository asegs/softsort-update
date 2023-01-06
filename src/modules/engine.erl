-module(engine).
-export([top_k_scores/6]).

zip4([],_,_,_) ->
  [];
zip4([W|Ws], [X|Xs], [Y|Ys], [Z|Zs]) ->
  [{W,X,Y,Z}|zip4(Ws, Xs, Ys, Zs)].

score_schema_in_option({Option, {SchemaType, Selection, Weight, MinMax}}) ->
  if SchemaType == <<"list">> ->
    Weight * calculate:score_list(Option, Selection) ;
    SchemaType == <<"math">> ->
      {Lower, Upper, Harshness, Direction} = Selection,
      [Min,Max | _] = MinMax,
      Weight * calculate:score_value_range(Option, Lower, Upper, Harshness, Direction, Min, Max) ;
    SchemaType == <<"set">> ->
      Weight * calculate:score_membership(Option, Selection)
  end.


score_option([Id, Name | Option_Data],Meta_List, Perfect_Score) ->
  Entries = lists:zip(Option_Data, Meta_List),
  Score = lists:sum(lists:map(fun score_schema_in_option/1, Entries)),
  {Id, Name, Score/Perfect_Score}.

rank(SchemaTypes, Options, Selections, Weights, MinMax) ->
  PerfectScore = lists:sum(Weights),
  PerEach = zip4(SchemaTypes,Selections,Weights,MinMax),
  lists:map(fun(Option)->score_option(Option, PerEach, PerfectScore) end, Options).

get_top_k_unordered(RankedList, K, Lower, Upper) ->
  Avg = (Lower + Upper) / 2,
  Remaining = [X || X <- RankedList, element(3, X) > Avg],
  if
    length(Remaining) =< K-> get_top_k_unordered(RankedList, K, Lower, Avg);
    length(Remaining) =< K * 2 -> Remaining;
    true -> get_top_k_unordered(RankedList, K, Avg, Upper)
  end.

get_top_k_by_qs(RankedList, K) ->
  Unordered = get_top_k_unordered(RankedList, K, 0, 100),
  Ordered =  lists:keysort(3, Unordered),
  lists:sublist(Ordered, length(Ordered) - K, length(Ordered)).

top_k_scores(SchemaTypes, Options, Selections, Weights, MinMax, K) ->
  Scores = rank(SchemaTypes, Options, Selections, Weights, MinMax),
  get_top_k_by_qs(Scores, K).

