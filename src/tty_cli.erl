%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2005-2018. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

%%
%% Description: a gen_server implementing a simple
%% terminal (using the group module) for a CLI
%% over SSH

-module(tty_cli).

-include("tty_pty.hrl").

-export([io_request/4,to_group/2]).


to_group([], _Group) ->
    ok;
to_group([$\^C | Tail], Group) ->
    exit(Group, interrupt),
    to_group(Tail, Group);
to_group(Data, Group) ->
    Func = fun(C) -> C /= $\^C end,
    Tail = case lists:splitwith(Func, Data) of
        {[], Right} ->
            Right;
        {Left, Right} ->
            Group ! {self(), {data, Left}},
            Right
    end,
    to_group(Tail, Group).

%%--------------------------------------------------------------------
%%% io_request, handle io requests from the user process,
%%% Note, this is not the real I/O-protocol, but the mockup version
%%% used between edlin and a user_driver. The protocol tags are
%%% similar, but the message set is different.
%%% The protocol only exists internally between edlin and a character
%%% displaying device...
%%% We are *not* really unicode aware yet, we just filter away characters
%%% beyond the latin1 range. We however handle the unicode binaries...
io_request({window_change, OldTty}, Buf, Tty, _Group) ->
    window_change(Tty, OldTty, Buf);
io_request({put_chars, Cs}, Buf, Tty, _Group) ->
    put_chars(bin_to_list(Cs), Buf, Tty);
io_request({put_chars, unicode, Cs}, Buf, Tty, _Group) ->
    put_chars(unicode:characters_to_list(Cs,unicode), Buf, Tty);
io_request({insert_chars, Cs}, Buf, Tty, _Group) ->
    insert_chars(bin_to_list(Cs), Buf, Tty);
io_request({insert_chars, unicode, Cs}, Buf, Tty, _Group) ->
    insert_chars(unicode:characters_to_list(Cs,unicode), Buf, Tty);
io_request({move_rel, N}, Buf, Tty, _Group) ->
    move_rel(N, Buf, Tty);
io_request({delete_chars,N}, Buf, Tty, _Group) ->
    delete_chars(N, Buf, Tty);
io_request(beep, Buf, _Tty, _Group) ->
    {[7], Buf};

%% New in R12
io_request({get_geometry,columns},Buf,Tty, _Group) ->
    {ok, Tty#tty_pty.width, Buf};
io_request({get_geometry,rows},Buf,Tty, _Group) ->
    {ok, Tty#tty_pty.height, Buf};
io_request({requests,Rs}, Buf, Tty, Group) ->
    io_requests(Rs, Buf, Tty, [], Group);
io_request(tty_geometry, Buf, Tty, Group) ->
    io_requests([{move_rel, 0}, {put_chars, unicode, [10]}],
                Buf, Tty, [], Group);
     %{[], Buf};

%% New in 18
io_request({put_chars_sync, Class, Cs, Reply}, Buf, Tty, Group) ->
    %% We handle these asynchronous for now, if we need output guarantees
    %% we have to handle these synchronously
    Group ! {reply, Reply},
    io_request({put_chars, Class, Cs}, Buf, Tty, Group);

io_request(_R, Buf, _Tty, _Group) ->
    {[], Buf}.

io_requests([R|Rs], Buf, Tty, Acc, Group) ->
    {Chars, NewBuf} = io_request(R, Buf, Tty, Group),
    io_requests(Rs, NewBuf, Tty, [Acc|Chars], Group);
io_requests([], Buf, _Tty, Acc, _Group) ->
    {Acc, Buf}.

%%% return commands for cursor navigation, assume everything is ansi
%%% (vt100), add clauses for other terminal types if needed
ansi_tty(N, L) ->
    ["\e[", integer_to_list(N), L].

get_tty_command(up, N, _TerminalType) ->
    ansi_tty(N, $A);
get_tty_command(down, N, _TerminalType) ->
    ansi_tty(N, $B);
get_tty_command(right, N, _TerminalType) ->
    ansi_tty(N, $C);
get_tty_command(left, N, _TerminalType) ->
    ansi_tty(N, $D).


-define(PAD, 10).
-define(TABWIDTH, 8).

%% convert input characters to buffer and to writeout
%% Note that the buf is reversed but the buftail is not
%% (this is handy; the head is always next to the cursor)
conv_buf([], AccBuf, AccBufTail, AccWrite, Col) ->
    {AccBuf, AccBufTail, lists:reverse(AccWrite), Col};
conv_buf([13, 10 | Rest], _AccBuf, AccBufTail, AccWrite, _Col) ->
    conv_buf(Rest, [], tl2(AccBufTail), [10, 13 | AccWrite], 0);
conv_buf([13 | Rest], _AccBuf, AccBufTail, AccWrite, _Col) ->
    conv_buf(Rest, [], tl1(AccBufTail), [13 | AccWrite], 0);
conv_buf([10 | Rest], _AccBuf, AccBufTail, AccWrite, _Col) ->
    conv_buf(Rest, [], tl1(AccBufTail), [10, 13 | AccWrite], 0);
conv_buf([C | Rest], AccBuf, AccBufTail, AccWrite, Col) ->
    conv_buf(Rest, [C | AccBuf], tl1(AccBufTail), [C | AccWrite], Col + 1).


%%% put characters at current position (possibly overwriting
%%% characters after current position in buffer)
put_chars(Chars, {Buf, BufTail, Col}, _Tty) ->
    {NewBuf, NewBufTail, WriteBuf, NewCol} =
	conv_buf(Chars, Buf, BufTail, [], Col),
    {WriteBuf, {NewBuf, NewBufTail, NewCol}}.

%%% insert character at current position
insert_chars([], {Buf, BufTail, Col}, _Tty) ->
    {[], {Buf, BufTail, Col}};
insert_chars(Chars, {Buf, BufTail, Col}, Tty) ->
    {NewBuf, _NewBufTail, WriteBuf, NewCol} =
	conv_buf(Chars, Buf, [], [], Col),
    M = move_cursor(special_at_width(NewCol+length(BufTail), Tty), NewCol, Tty),
    {[WriteBuf, BufTail | M], {NewBuf, BufTail, NewCol}}.

%%% delete characters at current position, (backwards if negative argument)
delete_chars(0, {Buf, BufTail, Col}, _Tty) ->
    {[], {Buf, BufTail, Col}};
delete_chars(N, {Buf, BufTail, Col}, Tty) when N > 0 ->
    NewBufTail = nthtail(N, BufTail),
    M = move_cursor(Col + length(NewBufTail) + N, Col, Tty),
    {[NewBufTail, lists:duplicate(N, $ ) | M],
     {Buf, NewBufTail, Col}};
delete_chars(N, {Buf, BufTail, Col}, Tty) -> % N < 0
    NewBuf = nthtail(-N, Buf),
    NewCol = case Col + N of V when V >= 0 -> V; _ -> 0 end,
    M1 = move_cursor(Col, NewCol, Tty),
    M2 = move_cursor(special_at_width(NewCol+length(BufTail)-N, Tty), NewCol, Tty),
    {[M1, BufTail, lists:duplicate(-N, $ ) | M2],
     {NewBuf, BufTail, NewCol}}.

%%% Window change, redraw the current line (and clear out after it
%%% if current window is wider than previous)
window_change(Tty, OldTty, Buf)
  when OldTty#tty_pty.width == Tty#tty_pty.width ->
    {[], Buf};
window_change(Tty, OldTty, {Buf, BufTail, Col}) ->
    M1 = move_cursor(Col, 0, OldTty),
    N = erlang:max(Tty#tty_pty.width - OldTty#tty_pty.width, 0) * 2,
    S = lists:reverse(Buf, [BufTail | lists:duplicate(N, $ )]),
    M2 = move_cursor(length(Buf) + length(BufTail) + N, Col, Tty),
    {[M1, S | M2], {Buf, BufTail, Col}}.

%% move around in buffer, respecting pad characters
step_over(0, Buf, [?PAD | BufTail], Col) ->
    {[?PAD | Buf], BufTail, Col+1};
step_over(0, Buf, BufTail, Col) ->
    {Buf, BufTail, Col};
step_over(N, [C | Buf], BufTail, Col) when N < 0 ->
    N1 = ifelse(C == ?PAD, N, N+1),
    step_over(N1, Buf, [C | BufTail], Col-1);
step_over(N, Buf, [C | BufTail], Col) when N > 0 ->
    N1 = ifelse(C == ?PAD, N, N-1),
    step_over(N1, [C | Buf], BufTail, Col+1).

%%% col and row from position with given width
col(N, W) -> N rem W.
row(N, W) -> N div W.

%%% move relative N characters
move_rel(N, {Buf, BufTail, Col}, Tty) ->
    {NewBuf, NewBufTail, NewCol} = step_over(N, Buf, BufTail, Col),
    M = move_cursor(Col, NewCol, Tty),
    {M, {NewBuf, NewBufTail, NewCol}}.

%%% give move command for tty
move_cursor(A, A, _Tty) ->
    [];
move_cursor(From, To, #tty_pty{width=Width, term=Type}) ->
    Tcol = case col(To, Width) - col(From, Width) of
	       0 -> "";
	       I when I < 0 -> get_tty_command(left, -I, Type);
	       I -> get_tty_command(right, I, Type)
	end,
    Trow = case row(To, Width) - row(From, Width) of
	       0 -> "";
	       J when J < 0 -> get_tty_command(up, -J, Type);
	       J -> get_tty_command(down, J, Type)
	   end,
    [Tcol | Trow].

%%% Caution for line "breaks"
special_at_width(From0, #tty_pty{width=Width}) when (From0 rem Width) == 0 -> From0 - 1;
special_at_width(From0, _) -> From0.

%%% tail, works with empty lists
tl1([_|A]) -> A;
tl1(_) -> [].

%%% second tail
tl2([_,_|A]) -> A;
tl2(_) -> [].

%%% nthtail as in lists, but no badarg if n > the length of list
nthtail(0, A) -> A;
nthtail(N, [_ | A]) when N > 0 -> nthtail(N-1, A);
nthtail(_, _) -> [].

ifelse(Cond, A, B) ->
    case Cond of
	true -> A;
	_ -> B
    end.

bin_to_list(B) when is_binary(B) ->
    binary_to_list(B);
bin_to_list(L) when is_list(L) ->
    lists:flatten([bin_to_list(A) || A <- L]);
bin_to_list(I) when is_integer(I) ->
    I.


