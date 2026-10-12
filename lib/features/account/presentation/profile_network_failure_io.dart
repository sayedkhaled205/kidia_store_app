import 'dart:io';

// Socket interruptions and incomplete HTTP headers have no response body.
// Certificate/handshake errors and malformed payloads deliberately do not match.
bool isRecoverableProfileNetworkCause(Object? error) =>
    error is SocketException || error is HttpException;
