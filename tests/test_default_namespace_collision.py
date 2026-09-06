"""Regression test for a real bug found by hand: five browser games --
connect4, digit_guess, pong, stickfight, roadfighter -- all registered
identically-named `create_room` / `join_room` / `start_game` / `leave_room`
handlers on Socket.IO's default namespace (``/``).

Flask-SocketIO keeps only the *last* registration for a given
(namespace, event) pair; each new `@socketio.on(...)` call for the same name
silently replaces the previous one rather than adding a second listener.
Since `register_roadfighter_events` was the last of the five to run (see
app.py's registration order), Road Fighter's handlers were the only ones
actually reachable -- and Road Fighter's own handlers immediately return if
`data.get('game_type') != 'roadfighter'`. So clicking "Create Room" on the
Connect4, Digit Guess, Pong, or Stick Fight page emitted `create_room`,
which *did* reach the server (Road Fighter's handler), which then silently
discarded it: no response, no error, nothing -- exactly the "clicking
Create does nothing" symptom, with no exception anywhere to point at it.

The fix mirrors the pattern already used for the native iOS/tvOS hub: give
each of these five games its own dedicated namespace instead of sharing the
default one. This test proves it by exercising the exact path that was
broken -- a `create_room` emit from each game's own client onto its own
namespace -- and confirms every one of them (not just whichever game
happened to register last) gets its own real response.
"""

import pytest

from app import create_app


@pytest.fixture
def server():
    return create_app("default")  # returns (app, socketio)


@pytest.mark.parametrize(
    "namespace,game_type,extra_payload",
    [
        ("/connect4", "connect4", {}),
        ("/digit_guess", "digit_guess", {}),
        ("/pong", "pong", {}),
        ("/stickfight", "stickfight", {}),
        ("/roadfighter", "roadfighter", {}),
    ],
)
def test_create_room_reaches_its_own_game_not_roadfighter(
    server, namespace, game_type, extra_payload
):
    app, socketio = server
    client = socketio.test_client(app, namespace=namespace)
    assert client.is_connected(namespace)

    payload = {"game_type": game_type, "player_name": "Tester"}
    payload.update(extra_payload)
    client.emit("create_room", payload, namespace=namespace)

    received = client.get_received(namespace)
    names = [e["name"] for e in received]

    # Before the namespace fix, every one of these except roadfighter
    # itself would receive nothing at all here -- their create_room was
    # being routed to roadfighter's handler, which silently discards any
    # payload whose game_type isn't 'roadfighter'.
    assert "room_created" in names, (
        f"create_room on {namespace} produced no response -- this is exactly "
        f"the 'clicking Create does nothing' bug: the event was silently "
        f"swallowed instead of reaching {game_type}'s own handler."
    )


def test_five_games_do_not_collide_on_the_default_namespace(server):
    """The five games' handlers must not be reachable on the bare default
    namespace at all -- if they were, that's the same collision returning
    in a different shape (all five stacked on '/' instead of stacked on
    one of themselves)."""
    app, socketio = server
    client = socketio.test_client(app)  # default namespace, no argument
    assert client.is_connected()

    client.emit("create_room", {"game_type": "connect4", "player_name": "Tester"})
    received = client.get_received()
    names = [e["name"] for e in received]

    assert "room_created" not in names, (
        "create_room on the default namespace still produced a response -- "
        "at least one of these five games is still registered on '/' "
        "instead of its own dedicated namespace."
    )
