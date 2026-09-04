"""Native iOS/tvOS game hub.

Isolated on its own Socket.IO namespace so it cannot collide with the browser
games, five of which register the same ``create_room``/``join_room`` event names
on the default namespace.
"""

NAMESPACE = "/native"

__all__ = ["NAMESPACE"]
