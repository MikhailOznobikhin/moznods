from rest_framework.throttling import UserRateThrottle


class LoginThrottle(UserRateThrottle):
    rate = "5/minute"
    scope = "login"


class MessagesThrottle(UserRateThrottle):
    rate = "60/minute"
    scope = "messages"


class RoomsThrottle(UserRateThrottle):
    rate = "30/minute"
    scope = "rooms"
