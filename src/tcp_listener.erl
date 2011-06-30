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

-module(tcp_listener).

-behaviour(gen_server).

-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).

-export([start_link/2]).

-record(state, {
	listener,
	acceptor
}).

start_link(Ip, Port) when is_integer(Port) ->
	gen_server:start_link(?MODULE, [Ip, Port], []).

init([Ip, Port]) ->
	process_flag(trap_exit, true),
%	Opts = [{ip, Ip}, binary, {packet, 2}, {reuseaddr, true}, {keepalive, true}, {backlog, 30}, {active, false}],
	Opts = [{ip, Ip}, binary, {packet, raw}, {reuseaddr, true}, {keepalive, true}, {backlog, 30}, {active, false}],
	case gen_tcp:listen(Port, Opts) of
		{ok, Socket} ->
			{ok, Ref} = prim_inet:async_accept(Socket, -1),
			{ok, #state{listener = Socket, acceptor = Ref}};
		{error, Reason} ->
			{stop, Reason}
	end.

handle_call(Request, _From, State) ->
	{stop, {unknown_call, Request}, State}.

handle_cast(_Msg, State) ->
	{noreply, State}.

handle_info({inet_async, ListSock, Ref, {ok, CliSocket}}, #state{listener=ListSock, acceptor=Ref} = State) ->
	case set_sockopt(ListSock, CliSocket) of
		ok -> ok;
		{error, Reason} -> exit({set_sockopt, Reason})
	end,

	gen_tcp:controlling_process(CliSocket, whereis(gen_amp_server)),
%	inet:setopts(CliSocket, [{active, once}, {packet, 2}, binary]),
	inet:setopts(CliSocket, [{active, once}, {packet, raw}, binary]),
	gen_server:cast(gen_amp_server, {accepted, CliSocket}),

	case prim_inet:async_accept(ListSock, -1) of
		{ok, NewRef} -> ok;
		{error, NewRef} -> exit({async_accept, inet:format_error(NewRef)})
        end,

	{noreply, State#state{acceptor=NewRef}};

handle_info({inet_async, ListSock, Ref, Error}, #state{listener=ListSock, acceptor=Ref} = State) ->
	error_logger:error_msg("Error in socket acceptor: ~p.\n", [Error]),
	{stop, Error, State};

handle_info(_Info, State) ->
	{noreply, State}.

terminate(_Reason, State) ->
	gen_tcp:close(State#state.listener),
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

set_sockopt(ListSock, CliSocket) ->
	true = inet_db:register_socket(CliSocket, inet_tcp),
	case prim_inet:getopts(ListSock, [active, nodelay, keepalive, delay_send, priority, tos]) of
		{ok, Opts} ->
			case prim_inet:setopts(CliSocket, Opts) of
				ok -> ok;
				Error -> gen_tcp:close(CliSocket), Error
			end;
		Error ->
			gen_tcp:close(CliSocket), Error
	end.
