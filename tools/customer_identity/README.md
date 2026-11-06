# Customer identity erasure — staged, not deployed

These services prepare the external-identity stage of customer account deletion.
They are not connected to the live WordPress deletion worker or enabled on the server.
The checked-in configuration defaults to disabled with no store/project mappings.

The Auth project must be explicitly mapped by authorized store ID. It is independent
of the push project. The authenticated connector route resolves the store; arbitrary
customer requests cannot choose the store or substitute an Auth project. The adapter
uses existing short-lived service credentials and needs only the project's
`firebaseauth.users.get` and `firebaseauth.users.delete` permissions. The live
read-only permission probe returned neither permission; no grants were changed.

Lookup validates the response shape and exact UID. Erasure compares the recorded
creation generation, deletes, and confirms absence with another lookup. Google
does not offer an atomic generation-conditional deletion. No account email, phone,
provider body, credential or upstream exception is returned or logged.

Before enabling any route, finish and verify: durable ownership linkage (including
shared UIDs), deletion intent/receipt ownership, server worker retry and recovery,
Apple authorization revocation, and the external account-deletion page. Never
activate these endpoints with a notification-only token without explicitly approving
its expanded deletion capability. Do not report account deletion complete based on
these clients alone. Do not test deletion against real customer accounts.

Offline synthetic checks:

```
php tools/customer_identity/tests/firebase-erasure-test.php
php tools/customer_identity/tests/store-identity-adapter-test.php
php tools/customer_identity/tests/identity-controller-test.php
```
