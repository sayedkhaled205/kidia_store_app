// Browser connection/timeout failures already have their explicit Dio kinds.
// An unidentified browser error is not permission to retain customer data.
bool isRecoverableProfileNetworkCause(Object? error) => false;
