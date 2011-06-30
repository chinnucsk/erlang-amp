%% Copyright (c) 2011 Peter Lemenkov.
%%
%% The MIT License
%%
%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.
%%

-module(gen_amp_sup).

-behaviour(supervisor).

-export([start_link/3]).
-export([init/1]).

start_link(Module, Ip, Port) ->
	supervisor:start_link({local, ?MODULE}, ?MODULE, [Module, Ip, Port]).

init([Module, Ip, Port]) ->
	MainProcess = {gen_amp_server, {gen_amp_server, start_link, [Module]}, permanent, 10000, worker, []},
	ListenProcess = {tcp_listener, {tcp_listener, start_link, [Ip, Port]}, permanent, 10000, worker, []},
	{ok, {{one_for_one, 10, 1}, [MainProcess, ListenProcess]}}.
