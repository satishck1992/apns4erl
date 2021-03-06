%% @doc Apple Push Notification Server for Erlang
-module(apns).
-author('Brujo Benavides <elbrujohalcon@inaka.net>').
-vsn('1.0.6').

-include("apns.hrl").
-include("localized.hrl").

-define(EPOCH, 62167219200).
-define(MAX_PAYLOAD, 2048).

-behaviour(application).

-export([start/0, stop/0]).
-export([connect/2, disconnect/1]).
-export([send_badge/3, send_message/2, send_message/3, send_message/4,
         send_message/5, send_message/6, send_message/7, send_message/8]).
-export([send_content_available/2, send_content_available/3]).
-export([estimate_available_bytes/1]).
-export([message_id/0, expiry/1, timestamp/1]).
-export([start/2, stop/1]).

-type status() :: no_errors
                | processing_error
                | missing_token
                | missing_topic
                | missing_payload
                | missing_token_size
                | missing_topic_size
                | missing_payload_size
                | invalid_token
                | unknown.
-export_type([status/0]).

-type connection() :: #apns_connection{}.
-export_type([connection/0]).

-type conn_id() :: atom() | pid().
-export_type([conn_id/0]).

-type apns_str() :: binary() | string().
-type alert() :: apns_str() | #loc_alert{}.
-export_type([alert/0]).

-type msg() :: #apns_msg{}.
-export_type([msg/0]).

%% @doc Starts the application
-spec start() -> ok | {error, {already_started, apns}}.
start() ->
  application:load(apns),
  case erlang:function_exported(application, ensure_all_started, 1) of
    false ->
      _ = application:start(crypto),
      _ = application:start(public_key),
      _ = application:start(ssl),
      application:start(apns);
    true ->
      _ = application:ensure_all_started(apns),
      ok
  end.

%% @doc Stops the application
-spec stop() -> ok.
stop() ->
  application:stop(apns).

%% ===================================================================
%% Application callbacks
%% ===================================================================
%% @hidden
-spec start(normal | {takeover, node()} | {failover, node()}, term()) ->
  {ok, pid()} | {error, term()}.
start(_StartType, _StartArgs) ->
    apns_sup:start_link().

%% @hidden
-spec stop([]) -> ok.
stop([]) -> ok.

%% @doc Opens an connection named after the atom()
%%      using the given feedback or error function
%%      or using the given connection() parameters
-spec connect(atom()| string() | fun((binary(), apns:status()) -> stop | _), 
              fun((string()) -> _) | connection()) ->
    {ok, pid()} | {error, {already_started, pid()}} | {error, Reason::term()}.
connect(Name, Connection) when is_record(Connection, apns_connection) ->
  apns_sup:start_connection(Name, Connection).


%% @doc Closes an open connection
-spec disconnect(conn_id()) -> ok.
disconnect(ConnId) ->
  apns_connection:stop(ConnId).

%% @doc Sends a message to Apple
-spec send_message(conn_id(), msg()) -> ok.
send_message(ConnId, Msg) ->
  apns_connection:send_message(ConnId, Msg).

%% @doc Sends a message to Apple with content_available: 1
-spec send_content_available(conn_id(), string()) -> ok.
send_content_available(ConnId, DeviceToken) ->
  send_message(ConnId, #apns_msg{device_token = DeviceToken,
                                 content_available = true,
                                 priority = 5}).

%% @doc Sends a message to Apple with content_available: 1 and an alert
-spec send_content_available(conn_id(), string(), string()) -> ok.
send_content_available(ConnId, DeviceToken, Alert) ->
  send_message(ConnId, #apns_msg{device_token = DeviceToken,
                                 content_available = true,
                                 alert = Alert}).

%% @doc Sends a message to Apple with just a badge
-spec send_badge(conn_id(), string(), integer()) -> ok.
send_badge(ConnId, DeviceToken, Badge) ->
  send_message(ConnId, #apns_msg{device_token = DeviceToken,
                                 badge = Badge}).

%% @doc Sends a message to Apple with just an alert
-spec send_message(conn_id(), string(), alert()) -> ok.
send_message(ConnId, DeviceToken, Alert) ->
  send_message(ConnId, #apns_msg{device_token = DeviceToken,
                                 alert = Alert}).

%% @doc Sends a message to Apple with an alert and a badge
-spec send_message(
  conn_id(), Token::string(), Alert::alert(), Badge::integer()) -> ok.
send_message(ConnId, DeviceToken, Alert, Badge) ->
  send_message(ConnId, #apns_msg{device_token = DeviceToken,
                                 badge = Badge,
                                 alert = Alert}).

%% @doc Sends a full message to Apple
-spec send_message(conn_id(), Token::string(), Alert::alert(), Badge::integer(),
                   Sound::apns_str()) -> ok.
send_message(ConnId, DeviceToken, Alert, Badge, Sound) ->
  send_message(ConnId, #apns_msg{alert = Alert,
                                 badge = Badge,
                                 sound = Sound,
                                 device_token = DeviceToken}).

%% @doc Predicts the number of bytes left in a message for additional data.
-spec estimate_available_bytes(msg()) -> integer().
estimate_available_bytes(#apns_msg{} = Msg) ->
  Payload = apns_connection:build_payload(Msg),
  ?MAX_PAYLOAD - erlang:size(Payload).

%% @doc Sends a full message to Apple (complete with expiry)
-spec send_message(conn_id(), Token::string(), Alert::alert(), Badge::integer(),
                   Sound::apns_str(), Expiry::non_neg_integer()) -> ok.
send_message(ConnId, DeviceToken, Alert, Badge, Sound, Expiry) ->
  send_message(ConnId, #apns_msg{alert = Alert,
                                 badge = Badge,
                                 sound = Sound,
                                 expiry= Expiry,
                                 device_token = DeviceToken}).

%% @doc Sends a full message to Apple with expiry and extra arguments
-spec send_message(conn_id(), Token::string(), Alert::alert(), Badge::integer(),
                   Sound::apns_str(), Expiry::non_neg_integer(),
                   ExtraArgs::proplists:proplist()) -> ok.
send_message(ConnId, DeviceToken, Alert, Badge, Sound, Expiry, ExtraArgs) ->
  send_message(ConnId, #apns_msg{alert = Alert,
                                 badge = Badge,
                                 sound = Sound,
                                 extra = ExtraArgs,
                                 expiry= Expiry,
                                 device_token = DeviceToken}).

%% @doc Sends a full message to Apple with id, expiry and extra arguments
-spec send_message(
  conn_id(), binary(), string(), alert(), integer(), apns_str(),
  non_neg_integer(), proplists:proplist()) -> ok.
send_message(
  ConnId, MsgId, DeviceToken, Alert, Badge, Sound, Expiry, ExtraArgs) ->
  send_message(ConnId, #apns_msg{id     = MsgId,
                                 alert  = Alert,
                                 badge  = Badge,
                                 sound  = Sound,
                                 extra  = ExtraArgs,
                                 expiry = Expiry,
                                 device_token = DeviceToken}).

%% @doc  Generates an "unique" and valid message Id
-spec message_id() -> binary().
message_id() ->
  {_, _, MicroSecs} = os:timestamp(),
  Secs = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
  First = Secs rem 65536,
  Last = MicroSecs rem 65536,
  <<First:2/unsigned-integer-unit:8, Last:2/unsigned-integer-unit:8>>.

%% @doc  Generates a valid expiry value for messages.
%%       If called with <code>none</code> as the parameter, it will return a
%%       <code>no-expire</code> value.
%%       If called with a datetime as the parameter, it will convert it to a
%%       valid expiry value.
%%       If called with an integer, it will add that many seconds to current
%%       time and return a valid expiry value for that date.
-spec expiry(
  none | {{1970..9999, 1..12, 1..31}, {0..24, 0..60, 0..60}} | pos_integer()) ->
    non_neg_integer().
expiry(none) -> 0;
expiry(Secs) when is_integer(Secs) ->
  calendar:datetime_to_gregorian_seconds(calendar:universal_time())
    - ?EPOCH + Secs;
expiry(Date) ->
  calendar:datetime_to_gregorian_seconds(Date) - ?EPOCH.

-spec timestamp(pos_integer()) -> calendar:datetime().
timestamp(Secs) ->
  calendar:gregorian_seconds_to_datetime(Secs + ?EPOCH).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_env(K, Def) ->
  case application:get_env(apns, K) of
    {ok, V} -> V;
    _ -> Def
  end.

